#!/usr/bin/env ruby

require "lib/Trac_Migrate"
require 'pp'

options=Hash.new
# config files. Later ones override earlier ones
options[:config_files] = ["migrate.yaml", "migrate-site.yaml"]

migrate = TracMigrate.new(options=options)
migrate.migrate_tickets
#migrate.go



