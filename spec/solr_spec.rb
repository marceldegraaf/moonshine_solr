require File.join(File.dirname(__FILE__), 'spec_helper.rb')

describe "A manifest with the Solr plugin" do

  before do
    @manifest = SolrManifest.new
    @manifest.solr
  end

  it "should be executable" do
    @manifest.should be_executable
  end

  it 'should install the solr-jetty package' do
    @manifest.should have_package('solr-jetty')
  end

  it 'should chown the Jetty log directory' do
    config = {
      :application => 'foobar',
      :user => 'foo',
      :deploy_to => '/srv/bar'
    }
    @manifest.configure(config)

    @manifest.should exec_command('chown -R foo /var/log/jetty')
  end

  it 'should logrotate the jetty log' do

  end

  it 'should start Jetty' do
    @manifest.should exec_command('/etc/init.d/jetty start')
  end

  it 'should create Solr config directories' do
    solr_dir = @manifest.files['/etc/solr']
    solr_dir.should_not be_nil
    solr_dir.ensure.should == :directory

    conf_dir = @manifest.files['/etc/solr/conf']
    conf_dir.should_not be_nil
    conf_dir.ensure.should == :directory
  end

  it 'should create config files' do
    @manifest.should have_file('/etc/default/jetty')
    @manifest.should have_file('/etc/solr/conf/elevate.xml')
    @manifest.should have_file('/etc/solr/conf/schema.xml')
    @manifest.should have_file('/etc/solr/solrconfig.xml')
    @manifest.should have_file('/etc/solr/conf/spellings.txt')
    @manifest.should have_file('/etc/solr/conf/stopwords.txt')
    @manifest.should have_file('/etc/solr/conf/synonyms.txt')
  end

end