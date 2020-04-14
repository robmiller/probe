#!/usr/bin/env ruby

require_relative "../lib/probe/probe"

urls_file = ARGV[0]
unless File.exist?(urls_file.to_s)
  warn "File doesn't exist"
  abort
end

sites = File.read(urls_file).each_line.map { |l| l.chomp.split("\t") }

sites.each do |name, url|
  probe = Probe.new(url, name: name)
  puts "#{name}\t#{url}\t#{probe.cms}"
end
