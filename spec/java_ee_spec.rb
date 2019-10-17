RSpec.describe "Java 11 Application" do

  before(:each) do
    clear_system_properties(app.directory)
    set_wildfly_version(app.directory, wildfly_version)
    set_java_version(app.directory, jdk_version)
    init_app(app)
    set_maven_custom_opts("-P deployment,skip-frontend-build -DskipTests")
  end

  def expect_successful_maven_build(jdk_version)
    expect(app.output).to include("Installing JDK #{jdk_version}")
    expect(app.output).to include("BUILD SUCCESS")
    expect(app.output).not_to include("BUILD FAILURE")
  end

  def set_maven_custom_opts(custom_opts)
    app.set_config({
      MAVEN_CUSTOM_OPTS: custom_opts,
    })
  end

  context "collaborative-markdown-editor" do
    let(:app) do
      Hatchet::Runner.new("collaborative-markdown-editor",
                          buildpacks: ["heroku/java", "mterhart/wildfly"],
                          allow_failure: false)
    end

    [
      "16.0.0.Final",
      "17.0.0.Final",
      "18.0.0.Final"
    ].each do |version|
      context "on WildFly #{version}" do
        let(:wildfly_version) { version }
        let(:jdk_version) { "11" }

        it "deploys successfully" do
          app.deploy do |app|
            expect_successful_maven_build(jdk_version)
            expect(app.output).to include("Downloading WildFly #{wildfly_version} to cache")
            expect(app.output).to include("Installing WildFly #{wildfly_version}")

            expect(app).to be_deployed
          end
        end
      end
    end

    [
      "16.0.0.Final"
    ].each do |version|
      context "with WildFly #{version} environment" do
        let(:wildfly_version) { version }
        let(:jdk_version) { "11" }

        it "sets environment variables and deploys the WAR file(s)" do
          app.deploy do |app|
            expect_successful_maven_build(jdk_version)

            env = app.run("env")
            expect(env).to include("JBOSS_HOME")
            expect(env).to include("JBOSS_CLI")
            expect(env).to include("WILDFLY_VERSION")

            sleep 2 # make sure the run dynos don't overlap
            expect(app.run('ls "\\$JBOSS_HOME/standalone/deployments"')).to match(%r{.*.war})
          end
        end
      end
    end
  end

  after(:each) do
    app.teardown!
  end
end
