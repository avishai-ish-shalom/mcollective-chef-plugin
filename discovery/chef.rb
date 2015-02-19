require 'chef'

class Mcollective::Discovery::Chef
	class < self
		include ChefPartialSearchMixin

		def string_or_regex_filters(node)
			filter["identity"].map do |found, identity_filter|
				if identity_filter.match("^/")
					!!Regexp.new(identity_filter).match(node)
				else
					identity_filter == node
				end
			end.any?
		end

		def discover(filter, timeout, limit=0, client=nil)
			Chef::Config.from_file(config.pluginconf["chef.config"] || "/etc/chef/client.rb")
			query = client.options.empty? ? "*:*" : client.options[:discovery_options].first
			facts = if filter["fact"].empty? 
						{}
					else
						Hash[filter["fact"].map {|f| [f, f.split(".")]}]
					end

			partial_search(:node, query, :keys => {:name => :name}.merge(facts)).values.select do |node|
				string_or_regex_filters(filter["identity"], node[:name])
			end
		end
	end
end