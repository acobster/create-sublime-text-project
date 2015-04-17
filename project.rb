#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'json'
require 'shellwords'

class ProjectCreator
	CONFIG_PATH = ENV['HOME']+'/.project-config.json'
	CONFIG_KEY_FAVORITES = 'dir_path_favorites'

	EXT = '.sublime-project'
	DEFAULT_BINARY = "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"

	def parse_config path
		if File.exists? path
			return JSON.parse! File.read(path)
		else
			raise "No config file found: #{path}"
		end
	end

	def initialize
		@name = ARGV[0]

		@options = OpenStruct.new
		OptionParser.new do |opts|
			opts.banner = "Usage: project project_name [options]"

		    opts.on("-h", "--help", "Prints this help") do
		        puts opts
		        exit
		    end

			opts.on('-c', '--config PATH', "Path to config file") do |c|
				@config = parse_config c
			end
			@config = parse_config CONFIG_PATH if @config.nil?

			opts.on("-v", "--verbose", "Run verbosely") do |v|
			@options.verbose = v
			end

			# TODO allow multiple paths
			@options.dir_path = infer_path @config['dir_path']
			opts.on('-f', "--favorite FAVORITE", "Name of a favorite path setting") do |favorite|
				favorites = @config[CONFIG_KEY_FAVORITES]

				if favorites and favorites[favorite]
					@options.dir_path = infer_path favorites[favorite]
				end
			end
			opts.on('-p', "--path PATH", "Path of the folder to include in project") do |path|
			  	@options.dir_path = infer_path path
			end

			@options.project_path = File.join @config['project_dir'], @name+EXT
			opts.on("-j", "--project-path", "File to save project as") do |path|
				@options.project_path
			end

			@options.overwrite = false
			opts.on('-o', '--overwrite', 'Overwrite existing projects') do |o|
				@options.overwrite = o
			end

			@options.open = false
			opts.on('-n', '--open', 'Open the project upon creation') do |open|
				@options.open = open
			end
		end.parse!
	end

	def run!
		output "Creating new Sublime project: #{@name}"

		path = @options.dir_path
		puts path
		warn "Looks like #{path} doesn't exist...proceeding anyway" unless Dir.exists? path
		output "Adding folder #{path}"

		project = {
			"folders" => [
				{
					"follow_symlinks" => true,
					"path" => path
				},
			]
		}

		if File.exists? @options.project_path and not @options.overwrite
			raise "#{@options.project_path} exists! Specify -o to overwrite"
		end

		message = ( File.exists? @options.project_path ) ?
			"#{@options.project_path} exists; overwriting" :
			"Writing to #{@options.project_path}"
		output message

		file = File.open @options.project_path, 'w'
		file.write project.to_json
		file.close

		output "Checking new project file..."
		begin
			JSON.parse File.read( @options.project_path )
			output "Project file looks okay!"
		rescue JSON::ParserError => e
			puts "OH NO! D: The project file has some bad JSON:"
			puts e.message
		end

		open_project if @options.open

		self
	rescue Exception => e
		puts e.message
		puts e.backtrace
	end

	def open_project
		raise "Can't find Sublime binary: #{binary}" unless File.exists? binary
		`#{binary.shellescape} --project #{@options.project_path}`
	end

	def output str
		puts str if @options[:verbose]
	end

	def infer_path path_str
		return if path_str.nil?
		path_str['{NAME}'] = @name if path_str['{NAME}']
		path_str
	end

	def binary
		@config['binary'] || DEFAULT_BINARY
	end
end


ProjectCreator.new.run!

