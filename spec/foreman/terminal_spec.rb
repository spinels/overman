require "spec_helper"
require "foreman"
require "rbconfig"
require "timeout"
require "tmpdir"
require "pty" unless Foreman.windows?

describe "Managed process terminal input", :unless => Foreman.windows? do
  it "does not stop the process group when a child attempts terminal access" do
    Dir.mktmpdir("overman-terminal") do |dir|
      File.write("#{dir}/child.rb", <<~RUBY)
        File.write("#{dir}/child.pid", Process.pid)
        system("stty raw")
        puts "stdin closed" if STDIN.read == ""
      RUBY
      File.write("#{dir}/launcher.rb", <<~RUBY)
        require #{File.expand_path("../../lib/foreman/process", __dir__).inspect}
        process = Foreman::Process.new(#{"#{RbConfig.ruby} #{dir}/child.rb".inspect})
        Process.wait(process.run)
      RUBY

      PTY.spawn(RbConfig.ruby, "#{dir}/launcher.rb") do |reader, writer, supervisor|
        begin
          output = ""
          Timeout.timeout(10) do
            output << reader.readpartial(4096) until output.include?("stdin closed")
          end
          expect(output).to include("stdin closed")
        ensure
          if File.size?("#{dir}/child.pid")
            Process.kill("KILL", -File.read("#{dir}/child.pid").to_i) rescue nil
          end
          Process.kill("KILL", supervisor) rescue nil
          Process.wait(supervisor) rescue nil
          reader.close unless reader.closed?
          writer.close unless writer.closed?
        end
      end
    end
  end
end
