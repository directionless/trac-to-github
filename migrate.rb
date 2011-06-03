#!/usr/bin/env ruby

require "lib/Trac_Migrate"
require 'pp'

options=Hash.new
options[:config_files] = ["migrate.yaml"]

migrate = TracMigrate.new(options=options)
migrate.migrate_tickets
#migrate.go



