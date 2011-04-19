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
    install_dependencies
    create_config_files
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
           :command => "chown -R #{configuration[:user]} /var/log/jetty",
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
    def create_config_files
      file '/etc/solr', :ensure => :directory
      file '/etc/solr/conf', :ensure => :directory

      config_files.each do |config_file|
        create_file_from_template(config_file[:file_name], config_file[:template_path])
      end
    end

    #
    # These templates will be copied to their respective +file_name+.
    #
    def config_files
      [
        {:file_name => '/etc/default/jetty',            :template_path => 'default_jetty.erb'},
        {:file_name => '/etc/solr/conf/elevate.xml',    :template_path => 'elevate.xml.erb'},
        {:file_name => '/etc/solr/conf/schema.xml',     :template_path => 'schema.xml.erb'},
        {:file_name => '/etc/solr/conf/solrconfig.xml', :template_path => 'solrconfig.xml.erb'},
        {:file_name => '/etc/solr/conf/spellings.txt',  :template_path => 'spellings.txt.erb'},
        {:file_name => '/etc/solr/conf/stopwords.txt',  :template_path => 'stopwords.txt.erb'},
        {:file_name => '/etc/solr/conf/synonyms.txt',   :template_path => 'synonyms.txt.erb'}
      ]
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
end