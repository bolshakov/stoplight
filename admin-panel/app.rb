# coding: utf-8

require 'sinatra'
require './lib/sinatra/stoplight_admin'

REDIS_URL = 'redis://localhost:6379'
set :data_store, Stoplight::DataStore::Redis.new(url: REDIS_URL)
