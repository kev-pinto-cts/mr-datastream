# Load remaining variables
require 'yaml'
vars = YAML.load(File.read("test/variables/#{input('input_env_name')}.json"))

control 'gcp' do
  describe google_sql_database_instance(project: 'output_project', database: '') do
    it { should exist }
    its('state') { should eq 'RUNNABLE' }
    its('backend_type') { should eq 'SECOND_GEN' }
    its('database_version') { should eq 'POSTGRES_12' }
  end
end

control 'local' do
end
