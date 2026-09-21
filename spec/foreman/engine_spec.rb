require "spec_helper"
require "foreman/engine"

class Foreman::Engine::Tester < Foreman::Engine
  attr_reader :buffer

  def startup
    @buffer = ""
  end

  def output(name, data)
    @buffer += "#{name}: #{data}"
  end

  def shutdown
  end
end

describe "Foreman::Engine", :fakefs do
  subject do
    write_procfile "Procfile"
    Foreman::Engine::Tester.new.load_procfile("Procfile")
  end

  describe "initialize" do
    describe "with a Procfile" do
      before { write_procfile }

      it "reads the processes" do
        expect(subject.process("alpha").command).to eq("./alpha")
        expect(subject.process("bravo").command).to eq("./bravo")
      end
    end
  end

  describe "start" do
    it "forks the processes" do
      expect(subject.process("alpha")).to receive(:run)
      expect(subject.process("bravo")).to receive(:run)
      expect(subject).to receive(:watch_for_output)
      expect(subject).to receive(:wait_for_shutdown_or_child_termination)
      subject.start
    end

    it "handles concurrency" do
      subject.options[:formation] = "alpha=2"
      expect(subject.process("alpha")).to receive(:run).twice
      expect(subject.process("bravo")).to_not receive(:run)
      expect(subject).to receive(:watch_for_output)
      expect(subject).to receive(:wait_for_shutdown_or_child_termination)
      subject.start
    end
  end

  describe "directories" do
    it "has the directory default relative to the Procfile" do
      write_procfile "/some/app/Procfile"
      engine = Foreman::Engine.new.load_procfile("/some/app/Procfile")
      expect(engine.root).to eq("/some/app")
    end
  end

  describe "shutdown", :unless => Foreman.windows? do
    before do
      subject.options[:formation] = "alpha=1"
      allow(subject.process("alpha")).to receive(:run) do |options|
        @process_writer = options[:output]
        1234
      end
      subject.startup
      subject.send(:spawn_processes)
    end

    let(:status) { instance_double(Process::Status, :exitstatus => 0, :exited? => true) }

    it "warns and stops tracking a group it cannot signal" do
      reaped = false
      allow(Process).to receive(:wait2) do
        raise Errno::ECHILD if reaped
        reaped = true
        [1234, status]
      end
      allow(Process).to receive(:kill).and_raise(Errno::EPERM)
      expect(subject).not_to receive(:sleep)

      subject.send(:terminate_gracefully)

      expect(subject.buffer).to include("WARNING: permission denied signaling process group 1234")
      expect(subject.buffer).not_to include("sending SIGKILL")
    end

    it "reaps and rechecks groups at the timeout before escalating" do
      subject.options[:timeout] = 0.2
      allow(Time).to receive(:now).and_return(Time.at(0), Time.at(1))
      polls = 0
      allow(Process).to receive(:wait2) do
        polls += 1
        polls == 2 ? [1234, status] : [nil, nil]
      end
      allow(Process).to receive(:kill).with(0, -1234) do
        raise Errno::ESRCH if polls >= 2
        1
      end
      expect(Process).to receive(:kill).with("-SIGTERM", 1234).and_return(1)
      expect(Process).not_to receive(:kill).with("-SIGKILL", 1234)

      subject.send(:terminate_gracefully)

      expect(subject.buffer).to include("exited with code 0")
      expect(subject.buffer).not_to include("sending SIGKILL")
    end

    it "keeps the process name while draining output after it exits" do
      reader = subject.instance_variable_get(:@readers).fetch(1234)
      subject.send(:handle_io, [reader])

      allow(Process).to receive(:wait2).and_return([1234, status])
      subject.send(:check_for_termination)
      allow(Process).to receive(:kill).with(0, -1234).and_raise(Errno::ESRCH)
      subject.send(:prune_process_groups)

      @process_writer.puts "buffered output"
      subject.send(:handle_io, [reader])

      expect(subject.buffer).to include("alpha.1: buffered output")
    end
  end

  describe "environment" do
    it "should read env files" do
      write_file("/tmp/env") { |f| f.puts("FOO=baz") }
      subject.load_env("/tmp/env")
      expect(subject.env["FOO"]).to eq("baz")
    end

    it "should read more than one if specified" do
      write_file("/tmp/env1") { |f| f.puts("FOO=bar") }
      write_file("/tmp/env2") { |f| f.puts("BAZ=qux") }
      subject.load_env "/tmp/env1"
      subject.load_env "/tmp/env2"
      expect(subject.env["FOO"]).to eq("bar")
      expect(subject.env["BAZ"]).to eq("qux")
    end

    it "should handle quoted values" do
      write_file("/tmp/env") do |f|
        f.puts 'FOO=bar'
        f.puts 'BAZ="qux"'
        f.puts "FRED='barney'"
        f.puts 'OTHER="escaped\"quote"'
        f.puts 'URL="http://example.com/api?foo=bar&baz=1"'
      end
      subject.load_env "/tmp/env"
      expect(subject.env["FOO"]).to   eq("bar")
      expect(subject.env["BAZ"]).to   eq("qux")
      expect(subject.env["FRED"]).to  eq("barney")
      expect(subject.env["OTHER"]).to eq('escaped"quote')
      expect(subject.env["URL"]).to   eq("http://example.com/api?foo=bar&baz=1")
    end

    it "should handle multiline strings" do
      write_file("/tmp/env") do |f|
        f.puts 'FOO="bar\nbaz"'
      end
      subject.load_env "/tmp/env"
      expect(subject.env["FOO"]).to eq("bar\nbaz")
    end

    it "should fail if specified and doesnt exist" do
      expect { subject.load_env "/tmp/env" }.to raise_error(Errno::ENOENT)
    end

    it "should set port from .env if specified" do
      write_file("/tmp/env") { |f| f.puts("PORT=9000") }
      subject.load_env "/tmp/env"
      expect(subject.send(:base_port)).to eq(9000)
    end
  end

end
