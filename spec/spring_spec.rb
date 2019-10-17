RSpec.describe "Spring Boot Application" do

  before(:each) do
    clear_system_properties(app.directory)
    set_wildfly_version(app.directory, wildfly_version)
    set_java_version(app.directory, jdk_version)
    init_app(app)
  end

  context "on WildFly 16.0.0.Final" do
    let(:app) do
      Hatchet::Runner.new("wildfly-spring-boot-sample",
                          buildpacks: ["heroku/java", "mterhart/wildfly"],
                          allow_failure: false)
    end
    let(:wildfly_version) { "16.0.0.Final" }
    let(:jdk_version) { "1.8" }

    it "deploys successfully and outputs Hello World" do
      app.deploy do |app|
        expect(app).to be_deployed
        expect(successful_body(app)).to eq("Hello World!")
      end
    end
  end

  after(:each) do
    app.teardown!
  end
end
