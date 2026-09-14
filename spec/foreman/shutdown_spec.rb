require "spec_helper"
require "foreman"
require "rbconfig"
require "timeout"
require "tmpdir"

describe "Process-group shutdown", :unless => Foreman.windows? do
  def wait_until
    Timeout.timeout(10) { sleep 0.02 until yield }
  end

  def alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  it "kills surviving descendants after their immediate parent exits" do
    Dir.mktmpdir("overman-shutdown") do |dir|
      File.write("#{dir}/service.rb", <<~RUBY)
        fork do
          trap("TERM", "IGNORE")
          File.write("#{dir}/descendant.pid", Process.pid)
          sleep
        end
        sleep
      RUBY
      File.write("#{dir}/Procfile", "service: #{RbConfig.ruby} service.rb\n")
      command = File.expand_path("../../bin/overman", __dir__)

      File.open("#{dir}/output", "w") do |output|
        supervisor = Process.spawn(RbConfig.ruby, command, "start", "-t", "1",
          :chdir => dir, :out => output, :err => output)
        begin
          wait_until { File.size?("#{dir}/descendant.pid") }
          descendant = File.read("#{dir}/descendant.pid").to_i
          group = Process.getpgid(descendant)
          Process.kill("INT", supervisor)
          Timeout.timeout(10) { Process.wait(supervisor) }

          wait_until { !alive?(descendant) }
          expect(File.read("#{dir}/output")).to include("sending SIGKILL")
        ensure
          Process.kill("KILL", -group) rescue nil if group
          Process.kill("KILL", supervisor) rescue nil
          Process.wait(supervisor) rescue nil
        end
      end
    end
  end
end
