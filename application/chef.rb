class MCollective::Application::Chef < MCollective::Application
	description "Control Chef on remote nodes"
	usage <<-EOS
mco chef [action] [options]

actions:
kick - signal a chef daemon to run
run - run chef and report the results
apply - run an ad-hoc recipe on nodes
EOS
	option  :run_list,
			:description => "Chef run list",
			:arguments => ["-r", "--run-list RUN_LIST"],
			:type => String

	option  :acquire_lock,
			:description => "Don't acquire Chef run lock",
			:arguments => ["--no-acquire-lock"],
			:type => :bool

	
	def post_option_parser(configuration)
		if ARGV.empty?
			puts "You must provide an action"
			exit 1
		else
			configuration[:action] = ARGV.shift
		end
		if configuration[:action] == "apply"
			configuration[:recipe_file] = ARGV.shift unless ARGV.empty?
		end
	end

	def validate_configuration(configuration)
		if configuration[:action] == "apply" and not (configuration[:recipe_file] and File.readable?(configuration[:recipe_file]))
			raise RuntimeError, "You must provide a recipe file with 'apply' action" 
		end
	end

	def main
		chef_rpc = rpcclient("chef")
		case configuration[:action]
		when "kick"
			printrpc chef_rpc.kick
		when "run"
			opts = {}
			opts[:run_list] = configuration[:run_list] if configuration[:run_list]
			# if --no-acquire-lock is given then configuration[:acquire_lock] will be magically set to false. nice.
			opts[:acquire_lock] = configuration[:acquire_lock]
			printrpc(chef_rpc.run(opts), :verbose => true)
		when "apply"
			opts = {}
			recipe_file = configuration[:recipe_file]
			puts "Applying Chef recipe from #{recipe_file}"
			opts[:recipe] = File.read(recipe_file)
			printrpc(chef_rpc.apply(opts), :verbose => true)
		end

		printrpcstats
		halt chef_rpc.stats
	end
end
