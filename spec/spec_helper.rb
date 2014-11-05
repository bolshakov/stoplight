# coding: utf-8

require 'coveralls'
Coveralls.wear!

require 'stoplight'
require 'timecop'

Dir.glob(File.join('.', 'spec', 'support', '**', '*.rb')).each do |filename|
  require filename
end

Timecop.safe_mode = true
