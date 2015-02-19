metadata :name        => "chef",
         :description => "Agent to manage Chef",
         :author      => "Avishai Ish-Shalom",
         :license     => "Apache V2",
         :version     => "0.1",
         :url         => "",
         :timeout     => 300

#requires :mcollective => "2.3.0"

action "kick", :description => "Kick Chef daemon to make it run now"

action "run", :description => "Run Chef on a node" do
	input   :run_list,
			:prompt => "Chef run list",
			:description => "Chef run list",
			:optional => true,
			:type => :string,
			:validation => "^((recipe|role)\\[[a-zA-Z0-9_:-]+\\],?)+$",
			:maxlength => 200
	input	:aqcuire_lock,
			:prompt => "Use chef run locking",
			:description => "Use global lock to prevent multiple Chef runs",
			:type => :boolean,
			:optional => true,
			:default => true

end

action "apply", :description => "Run an ad-hoc recipe" do
	input   :recipe,
			:prompt => "Chef recipe text",
			:description => "An ad-hoc Chef recipe to apply",
			:type => :string,
			:maxlength => 100000,
			:validation => ".*",
			:optional => false
end
