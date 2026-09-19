require "spec_helper"
require "foreman"
require "foreman/engine"
require "rbconfig"
require "timeout"
require "tmpdir"

describe "Process-group shutdown", :unless => Foreman.windows? do
  def wait_until
    Timeout.timeout(10) { sleep 0.02 until yield }
  end

  def stop_supervisor(pid)
    return if Process.waitpid(pid, Process::WNOHANG)

    Process.kill("INT", pid)
    begin
      Timeout.timeout(2) { Process.wait(pid) }
    rescue Timeout::Error
      Process.kill("KILL", pid)
      Process.wait(pid)
    end
  rescue Errno::ESRCH, Errno::ECHILD
    # The supervisor has already exited or been reaped by the example.
  end

  def with_supervisor(dir)
    command = File.expand_path("../../bin/overman", __dir__)
    output = "#{dir}/output"
    supervisor = Process.spawn(RbConfig.ruby, command, "start", "-t", "0.2",
      :chdir => dir, [:out, :err] => output)
    begin
      yield supervisor
    rescue Exception
      warn "Supervisor output:\n#{File.read(output)}"
      raise
    ensure
      stop_supervisor(supervisor)
      Dir["#{dir}/*.group"].each do |file|
        group = File.read(file).to_i
        Process.kill("KILL", -group) rescue nil if group > 0
      end
    end
  end

  it "kills surviving descendants after their immediate parent exits" do
    Dir.mktmpdir("overman-shutdown") do |dir|
      File.write("#{dir}/service.rb", <<~RUBY)
        File.write("service.group", Process.getpgrp)
        fork do
          trap("TERM", "IGNORE")
          File.open("descendant.lock", "w") do |lock|
            lock.flock(File::LOCK_EX)
            File.write("ready", "ready")
            sleep
          end
        end
        sleep
      RUBY
      File.write("#{dir}/Procfile", "service: #{RbConfig.ruby} service.rb\n")

      with_supervisor(dir) do |supervisor|
        wait_until { File.size?("#{dir}/ready") }
        File.open("#{dir}/descendant.lock", "r") do |lock|
          expect(lock.flock(File::LOCK_EX | File::LOCK_NB)).to eq(false)
          Process.kill("INT", supervisor)
          Timeout.timeout(10) { Process.wait(supervisor) }

          wait_until { lock.flock(File::LOCK_EX | File::LOCK_NB) }
        end
        expect(File.read("#{dir}/output")).to match(/terminated by SIGTERM.*sending SIGKILL/m)
      end
    end
  end

  it "signals later groups when an earlier group has disappeared" do
    Dir.mktmpdir("overman-signals") do |dir|
      File.write("#{dir}/service.rb", <<~RUBY)
        name = ARGV.fetch(0)
        File.write("\#{name}.group", Process.getpgrp)
        exit if name == "gone"
        trap("TERM") do
          File.write("terminated", "TERM")
          exit
        end
        File.write("ready", "ready")
        sleep
      RUBY
      File.write("#{dir}/Procfile", <<~PROCFILE)
        gone: #{RbConfig.ruby} service.rb gone
        remaining: #{RbConfig.ruby} service.rb remaining
      PROCFILE
      engine = Foreman::Engine.new.load_procfile("#{dir}/Procfile")
      begin
        engine.send(:spawn_processes)
        wait_until { File.size?("#{dir}/gone.group") && File.size?("#{dir}/ready") }
        gone = File.read("#{dir}/gone.group").to_i
        remaining = File.read("#{dir}/remaining.group").to_i
        Timeout.timeout(10) { Process.wait(gone) }
        expect { Process.kill(0, -gone) }.to raise_error(Errno::ESRCH)

        engine.kill_children

        Timeout.timeout(10) { Process.wait(remaining) }
        expect(File.read("#{dir}/terminated")).to eq("TERM")
      ensure
        Dir["#{dir}/*.group"].each do |file|
          group = File.read(file).to_i
          if group > 0
            Process.kill("KILL", -group) rescue nil
            Process.wait(group) rescue nil
          end
        end
      end
    end
  end
end
