require 'fileutils'
require 'open-uri'

namespace :rails_aux do
	RAILS_TEMPLATES_DIR = "~/.rake/templates/rails"
	
	def install_plugin(application_name, plugin_path)
		%x{ cd "#{application_name}"; ./script/plugin install "#{plugin_path}" }
	end
	
	def patch_file(filename, target_expression, patch_expression)
		aFile = ""
		File.open(filename) do |f|
			aFile = f.read
			aFile.sub!(target_expression) do |match|
				patch_expression.call($~)
			end
		end
		
		File.open(filename,"w") do |f|
			f.write(aFile)
		end
	end
	
	def apply_theme(application_name, theme_name)
		FileUtils.cp_r(File.expand_path(RAILS_TEMPLATES_DIR + "/themes/#{theme_name}") + "/.", 
			application_name + "/", :verbose => true)
	end
	
	desc "test task"
	task :test do
		application_name = ENV['app'] || "railsapplication"

		open("http://svn.danwebb.net/external/lowpro/tags/rel-0.2/dist/lowpro-0.2.zip") do |f|
			lowpro = f.read
			File.open(application_name + "/public/javascripts/lowpro")
		end
	end
	
	desc "Augmented rails command. Usage app=rails_app_name_and_path"
	task :augmented_rails do
		applicationName = ENV['app'] || "railsapplication"
		# #create rails application
	  %x{ rails "#{applicationName}" }
		#add haml interpreter
		%x{ haml --rails "#{applicationName}" }
		#JQuery environment
		#install_plugin(applicationName, "http://ennerchi.googlecode.com/svn/trunk/plugins/jrails")
		#rails-authorization-plugin
		install_plugin(applicationName, "git://github.com/DocSavage/rails-authorization-plugin.git")
		install_plugin(applicationName, "git://github.com/technoweenie/attachment_fu.git")
		install_plugin(applicationName, "git://github.com/mattetti/acts_as_taggable_on_steroids.git")
		install_plugin(applicationName, "git://github.com/cainlevy/recordselect.git")
		install_plugin(applicationName, "git://github.com/activescaffold/active_scaffold.git")
		install_plugin(applicationName, "git://github.com/delynn/userstamp.git")
 	  install_plugin(applicationName, "git://github.com/collectiveidea/awesome_nested_set.git")
		install_plugin(applicationName, "git://github.com/rails/acts_as_tree.git")
		install_plugin(applicationName, "git://github.com/funkensturm/acts_as_category.git")
		install_plugin(applicationName, "git://github.com/face/activity_streams.git")
#		install_plugin(applicationName, "git://github.com/linkingpaths/acts_as_scribe.git")
		install_plugin(applicationName, "git://github.com/simonmenke/rjs_behaviors.git")
		install_plugin(applicationName, "git://github.com/rails/auto_complete.git")
		
		patch_file(applicationName + "/config/environment.rb",/(^.*# config.gem)/, lambda { |match| "  config.gem \"authlogic\"\n#{match[1]}" })		
		patch_file(applicationName + "/config/environment.rb",/(^.*# config.gem)/, lambda { |match| "  config.gem \"searchlogic\"\n#{match[1]}" })
		patch_file(applicationName + "/config/environment.rb",/(^.*# config.gem)/, lambda { |match| "  config.gem \"paginator\"\n#{match[1]}" })
		
		apply_theme(applicationName, "web20")
		
		#remove default index file
		FileUtils.rm applicationName  + "/public/index.html"
		
		Rake::Task[ "rails_aux:authlogic_init" ].execute
		Rake::Task[ "rails_aux:acts_as_taggable_init" ].execute
		Rake::Task[ "rails_aux:authorization_plugin_init" ].execute
		Rake::Task[ "rails_aux:git_conditioning" ].execute		
		Rake::Task[ "rails_aux:userstamp_init" ].execute
		Rake::Task[ "rails_aux:rjs_behaviours_init" ].execute
	end
	
	desc "rjs_behaviours init"
	task :rjs_behaviours_init do
		application_name = ENV['app'] || "railsapplication"
		
		# ======================================================
		# 	- Please add the folowing line to your routes.rb file:
		# 	  map.behaviour 'javascripts/behaviours/:action.js',
		# 	    :controller => 'behaviours', :format => 'js'
		# 	- Please add the lowpro.js file to your layouts:
		# 	  <%= javascript_include_tag 'lowpro' %>
		# 	======================================================
				
		patch_file(application_name + "/config/routes.rb", 
			/^(  # See how all your routes lay out with "rake routes")$/,
		 	lambda { |match| 
				"#{match[1]}\n  map.behaviour 'javascripts/behaviours/:action.js',:controller => 'behaviours', :format => 'js'\n"
			}
		)
		
		template_behaviour_controller = <<-END
class BehavioursController < ApplicationController
  def general
    render :behaviours do
		  #behavior('#example') do |page, this|
		  #  this.add_class_name('boo')
		  #end
    end
  end
end
END
		File.open(application_name + "/app/controllers/behaviours_controller.rb").write(template_behaviour_controller)
	end
	
	desc "Userstamp plugin Initialize "
	task :userstamp_init do
		application_name = ENV['app'] || "railsapplication"

		patch_file(application_name + "/app/controllers/application.rb", 
			/^(class ApplicationController < ActionController::Base)$/,
		 	lambda { |match| 
				"#{match[1]}\n  include Userstamp"
			}
		)	
		
		patch_file(application_name + "/app/models/user.rb", 
			/^(class User < ActiveRecord::Base)$/,
			lambda { |match| "#{match[1]}\n  model_stamper\n  stampable\n"}
			)
		
		migration_template = <<-END
class AddUserstampsToUser < ActiveRecord::Migration
  def self.up
		add_column :users, :creator_id, :integer
		add_column :users, :updater_id, :integer
		add_column :users, :deleter_id, :integer
  end

  def self.down
		remove_column :users, :creator_id
		remove_column :users, :updater_id
		remove_column :users, :deleter_id

  end
end
END
		File.open(application_name + "/db/migrate/" +Time.now.strftime("%Y%m%d%H%M%S")+"_add_userstamps_to_user.rb","w").write(migration_template)
		%x{ cd "#{application_name}"; rake db:migrate }
	end

	desc "Authorization plugin initialization"
	task :authorization_plugin_init do
		application_name = ENV['app'] || "railsapplication"
		
		environment_config = <<-END
	  # Authorization plugin for role based access control
	  # You can override default authorization system constants here.

	  # Can be 'object roles' or 'hardwired'
	  AUTHORIZATION_MIXIN = "object roles"

	  # NOTE : If you use modular controllers like '/admin/products' be sure
	  # to redirect to something like '/sessions' controller (with a leading slash)
	  # as shown in the example below or you will not get redirected properly
	  #
	  # This can be set to a hash or to an explicit path like '/login'
	  #
	  LOGIN_REQUIRED_REDIRECTION = { :controller => '/user_sessions', :action => 'new' }
	  PERMISSION_DENIED_REDIRECTION = { :controller => '/home', :action => 'index' }

	  # The method your auth scheme uses to store the location to redirect back to
	  STORE_LOCATION_METHOD = :store_location
END

		patch_file(application_name + "/config/environment.rb", 
			/^(# Be sure to restart your server when you modify this file)$/,
			lambda { |match| "#{match[1]}\n#{environment_config}\n"}
			)

		%x{ cd "#{application_name}"; ./script/generate role_model Role; rake db:migrate }

		model_config = <<-MODEL
		# Authorization plugin config
    acts_as_authorized_user
    acts_as_authorizable
		# End Authorization plugin config
MODEL

		patch_file(application_name + "/app/models/user.rb", 
			/^(class User < ActiveRecord::Base)$/,
			lambda { |match| "#{match[1]}\n#{model_config}\n"}
			)
			
			
		# Patch pluralization error

		FileUtils.mv application_name  + "/app/models/role_user.rb", 
			application_name  + "/app/models/roles_user.rb"

		patch_file(application_name + "/app/models/roles_user.rb", 
			/^(class RoleUser < ActiveRecord::Base)$/,
			lambda { |match| "class RolesUser < ActiveRecord::Base\n"}
			)
	end
	
	desc "Git conditioning"
	task :git_conditioning do
		application_name = ENV['app'] || "railsapplication"

		git_ignore_template = <<-END
log/*
tmp/*
.DS_Store
public/files/*
files/*
db/*.sqlite3
END

		File.open(application_name + "/.gitignore","w").write(git_ignore_template)
	end
	
	desc "Act as taggable initialization"
	task :acts_as_taggable_init do
		application_name = ENV['app'] || "railsapplication"

		%x{ cd "#{application_name}"; ./script/generate acts_as_taggable_migration; rake db:migrate }
		
		patch_file(application_name + "/app/helpers/application_helper.rb", 
			/^(module ApplicationHelper)$/,
			lambda { |match| "#{match[1]}\n  include TagsHelper\n"}
			)		
		
	end
	
	desc "Authlogic plugin initialization"
	task :authlogic_init do
		application_name = ENV['app'] || "railsapplication"

		#Authlogic initialization
		%x{ cd "#{application_name}"; ./script/generate session user_session }
		
		FileUtils.cp File.expand_path(RAILS_TEMPLATES_DIR + "/authlogic/user_sessions_controller.rb"), application_name + "/app/controllers/user_sessions_controller.rb"
	  FileUtils.cp File.expand_path(RAILS_TEMPLATES_DIR + "/authlogic/users_controller.rb"), application_name + "/app/controllers/users_controller.rb"

		%x{ cd "#{application_name}"; script/generate model user login:string crypted_password:string \
		  password_salt:string persistence_token:string login_count:integer last_request_at:datetime last_login_at:datetime \
		  current_login_at:datetime last_login_ip:string current_login_ip:string
		}
		
		patch_file(application_name + "/app/models/user.rb", 
			/^(class User < ActiveRecord::Base)$/,
			lambda { |match| "#{match[1]}\n  acts_as_authentic\n"}
			)
			
		patch_file(application_name + "/config/routes.rb", 
			/^(ActionController::Routing::Routes.draw do |map|)$/,
			lambda { |match| "#{match[1]}\n  #AUTOGENERATED RESOURCE ROUTES\n  map.resource :account, :controller => \"users\"\n  map.resources :users\n  map.resource :user_session\n  map.root :controller => \"user_sessions\", :action => \"new\""}
			)			
			
		patch_file(application_name + "/app/controllers/application.rb", 
			/^(end)$/,
		 	lambda { |match| 
				myText = ""
				File.open(File.expand_path(RAILS_TEMPLATES_DIR + "/authlogic/application_controller.rb")) do |f|
					myText = f.read
				end
				"#{myText}\n#{match[1]}\n"
			}
		)	
		
		FileUtils.cp_r(File.expand_path(RAILS_TEMPLATES_DIR + "/authlogic/views"), application_name + "/app")
		
		%x{ cd "#{application_name}"; rake db:migrate }	
	end
	
	desc "Install standard pluggins"
	task :install_standard_pluggins do
		puts ENV['RAILS_ROOT'] || `pwd`
	end
end
