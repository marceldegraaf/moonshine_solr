module Solr
  # Define options for this plugin via the <tt>configure</tt> method
  # in your application manifest:
  #
  #    configure(:solr => {:port => 8182})
  #
  # Moonshine will autoload plugins, just call the recipe(s) you need in your
  # manifests:
  #
  #    recipe :solr
  def solr(options = {})
    @options = options

    install_dependencies
    create_config_files(options)
    chown_log_dir
    log_rotation

    start_jetty
  end

  private

    #
    # Takes care of installing all system dependencies
    # during the deployment, such as the JVM and Jetty.
    #
    def install_dependencies
      package 'solr-jetty', :ensure => :installed
    end

    #
    # Make sure the Moonshine user can write to the Jetty log dir.
    #
    def chown_log_dir
      exec 'chown log dir',
           :command => "chown -R #{moonshine_user} /var/log/jetty",
           :require => package('solr-jetty')
    end

    #
    # Schedule log rotation for Jetty.
    #
    def log_rotation
      logrotate '/var/log/jetty/*.log',
                :options => %w(weekly missingok compress),
                :postrotate => '/etc/init.d/jetty restart'
    end

    #
    # Boot her up!
    #
    def start_jetty
      exec 'Start Jetty',
           :command => '/etc/init.d/jetty start',
           :require => [
                         file('/etc/default/jetty'),
                         file('/etc/solr/conf/solrconfig.xml'),
                         file('/etc/solr/conf/schema.xml'),
                         package('solr-jetty')
                       ]
    end

    #
    # Create config files from each of the templates configured below.
    #
    def create_config_files(options)
      # Ensure the Solr configuration directory exists.
      file '/etc/solr', :ensure => :directory
      file '/etc/solr/conf', :ensure => :directory

      # Copy the default Jetty config file
      create_file_from_template '/etc/default/jetty', 'default_jetty.erb'

      # Create Solr config files
      solr_config_files.each do |solr_config_file|
        if should_use_local_config_file(solr_config_file) && local_config_file_exists(solr_config_file)
          use_local_config_file(solr_config_file)
        else
          create_file_from_template(solr_config_path(solr_config_file), config_file_template(solr_config_file))
        end
      end
    end

    #
    # The full list of config files that will be made available to Solr.
    #
    def solr_config_files
      %w(elevate.xml schema.xml solrconfig.xml spellings.txt stopwords.txt synonyms.txt)
    end

    #
    # Convenience method to create files from templates.
    #
    def create_file_from_template(file_name, template_path, mode = '644')
      file file_name,
           :ensure => :present,
           :mode => mode,
           :content => template(File.join(File.dirname(__FILE__), '..', 'templates', template_path), binding),
           :require => package('solr-jetty')
    end

    #
    # Convenience method to copy an existing (local) config file
    # and use it for Solr.
    #
    def use_local_config_file(config_file, mode = '644')
      file solr_config_path(config_file),
           :ensure => :present,
           :mode => mode,
           :content => File.join(deploy_path, 'solr', 'conf', config_file),
           :require => package('solr-jetty')
    end

    #
    # The user that runs the Rails application
    #
    def moonshine_user
      configuration[:user]
    end

    #
    # Path where the Rails application is deployed to.
    #
    def deploy_path
      configuration[:deploy_to]
    end

    #
    # Should +config_file+ be used from the Rails app source tree?
    #
    def should_use_local_config_file(config_file)
      return true if options[:use_my_config_files] == :all
      options[:use_my_config_files] && options[:use_my_config_files].is_a?(Array) && options[:use_my_config_files].include?(config_file)
    end

    #
    # Does +config_file+ exist in the Rails app source tree?
    #
    def local_config_file_exists(config_file)
      File.exists?(File.join(deploy_path, 'current', 'solr', 'conf', config_file))
    end

    #
    # Template file for +config_file+
    #
    def config_file_template(config_file)
      "#{config_file}.erb"
    end

    #
    # This is where all Solr configuration will be stored on the server.
    #
    def solr_config_path(config_file)
      File.join('/', 'etc', 'solr', 'conf', config_file)
    end

    #
    # Shortcut to provided options
    #
    def options
      @options ||= {}
    end

end