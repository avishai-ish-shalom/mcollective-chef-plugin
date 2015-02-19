require 'fcntl'

class MCollective::Agent::Chef < MCollective::RPC::Agent
	activate_when do
		File.executable?("/usr/bin/chef-solo")
	end

	action :kick do
		begin
			Process.kill("USR1", find_chef_pid)
		rescue Errno::ENOENT => e
			reply.fail "Could not find Chef pid"
		end
	end

	action :run do
		if request[:run_list]
			validate :run_list, String
			validate :run_list, /^(?:(?:recipe|role)\[[a-zA-Z0-9_:-]+\],?)+$/
			chef_opts = "-o #{request[:run_list]}"
		else
			chef_opts = ""
		end
		chef_type = request.fetch(:chef_type, config.pluginconf["chef.type"] || "client")
		raise RuntimeError, "chef type must be client or solo" unless %w(solo client).include?(chef_type)

		chef_run_proc = proc {run("/usr/bin/chef-#{chef_type} #{chef_opts}", :stderr => :err, :stdout => :out, :environment => {"GEM_PATH" => "", "GEM_HOME" => ""})}

		result = if request[:acquire_lock]
			acquire_shared_lock(&chef_run_proc)
		else
			chef_run_proc.call
		end

		case result
		when false
			reply.fail("Failed to obtain lock, Chef run is in progress", 0)
		when 0
		else
			reply.fail(result)
		end
		@logger.info("Chef #{chef_type} returned #{result}")

		reply[:result] = result
	end

	action :apply do
		temp_recipe = Tempfile.new(['mcollective-chef-apply', '.rb'])
		begin
			temp_recipe.write(request[:recipe])
			@logger.debug("Running command \"/usr/bin/chef-apply #{temp_recipe.path}\"")
			out, err = [], []
			reply[:result] = run("/usr/bin/chef-apply #{temp_recipe.path}", :stdout => out, :stderr => err)
			@logger.debug("stderr: #{err}")
			reply[:stderr], reply[:stdout] = err, out
		rescue Exception => e
			raise e
		ensure
			temp_recipe.close
			temp_recipe.unlink
		end
		@logger.info("Chef apply returned #{reply[:result]}")
		reply.fail("Chef run failed", reply[:result]) unless reply[:result] == 0
	end

	def find_chef_pid
		File.read(config.pluginconf["chef.pidfile"] || "/var/run/chef-client.pid").to_i
	end


	# Take a block, lock the lockfile then run the block
	# returns false if failed to obtain the lock, otherwise return the result of the run
	def acquire_shared_lock(&block)
		lockfile = config.pluginconf['chef.lockfile'] || "/var/cache/chef/chef-client-running.pid"
		@lockfile = File.open(lockfile, 'a+')
		if Fcntl.const_defined?('F_SETFD') and Fcntl.const_defined?('FD_CLOEXEC')
			@logger.debug("Calling fcntl on lockfile #{lockfile}")
			@lockfile.fcntl(Fcntl::F_SETFD, lockfile.fcntl(Fcntl::F_GETFD, 0) | Fcntl::FD_CLOEXEC)
		end

		@logger.debug("Trying to lock lockfile #{lockfile} using flock")
		lock_aqcuired = (!! @lockfile.flock(File::LOCK_NB | File::LOCK_SH))
		if lock_aqcuired
			@logger.debug("Lock obtained on lockfile #{lockfile}, calling block")
			res = block.call
			release_shared_lock
			@logger.debug("Lock released")
		else
			@logger.debug("Failed to lock lockfile #{lockfile}")
			res = false
		end
		return res
	end

	def release_shared_lock
		@lockfile.flock(File::LOCK_UN)
	end
end