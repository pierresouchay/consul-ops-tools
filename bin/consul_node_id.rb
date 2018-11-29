#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'optparse'

def usage_text
  "USAGE: #{__FILE__} [[options]]"
end

def generate_node_id_for_consul(baseid)
  h = Digest::SHA512.hexdigest(baseid)
  "#{h[0..7]}-#{h[8..11]}-#{h[12..15]}-#{h[16..19]}-#{h[20..31]}"
end

def write_to(value, dst)
  if dst
    begin
      file = File.open(dst, 'w')
      file.write(value)
    rescue StandardError => e
      STDERR.puts "[ERROR] Cannot write to #{dst}: #{e}"
      exit 1
    ensure
      file&.close
    end
  else
    puts value
  end
end

command_to_run = 'dmidecode -q  -s system-uuid'
dst = nil

optparse = OptionParser.new do |opts|
  opts.banner = usage_text

  opts.on('-h', '--help', 'Show help') do
    STDERR.puts opts
    exit 0
  end

  opts.on('-c', '--command=<seed>', String, "Seed to generate node-id (example: hostname -f), default=\"#{command_to_run}\"") do |seed|
    command_to_run = seed
  end

  opts.on('-w', '--write=<path>', String, 'Path to Write node-id to (example: /var/lib/consul/node-id, default: stdout') do |path|
    dst = path
  end
end

optparse.parse!

begin
  nodeid = generate_node_id_for_consul(`#{command_to_run}`.strip.downcase)
  raise 'Command did not generate any output!' unless nodeid
rescue StandardError => e
  STDERR.puts "[ERROR] Cannot get value from command '#{command_to_run}': #{e}"
  exit 2
end

write_to(nodeid, dst)

exit 0
