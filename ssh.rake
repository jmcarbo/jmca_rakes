namespace :ssh do
  desc "Add public ssh key to host: host=<host> user=<user>"
  task :add_key_to_host do
    host = ENV['host']
    user = ENV['user']
    
    `cat ~/.ssh/id_rsa.pub | ssh #{user}@#{host} 'mkdir ~/.ssh;chmod 700 ~/.ssh;touch ~/.ssh/authorized_keys2;chmod 600 ~/.ssh/authorized_keys2;cat - >> .ssh/authorized_keys2'`
    
  end
end