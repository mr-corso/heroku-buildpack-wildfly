RSpec.describe "WildFly" do

  context "on collaborative-markdown-editor" do
    let(:app) do
      Hatchet::Runner.new("collaborative-markdown-editor",
                          buildpacks: ["heroku/java", "mterhart/wildfly"],
                          allow_failure: false)
    end
    let(:wildfly_version) { "16.0.0.Final" }

    it "should deploy successfully" do
      app.setup!
      app.set_config({
        MAVEN_CUSTOM_OPTS: "-P deployment,skip-frontend-build -DskipTests",
      })

      app.deploy do |app|
        expect(app.output).to include("Downloading WildFly #{wildfly_version} to cache")
        expect(app.output).to include("Installing WildFly #{wildfly_version}")
        expect(app.output).to include("Deploying WAR file(s)")
        expect(app.output).to include("ROOT.war")
        expect(app.output).to include("Creating process configuration")
        expect(app.output).to include("Using existing process type 'web' in Procfile")

        expect(app).to be_deployed
      end
    end
  end
end
