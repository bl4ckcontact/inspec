require "helper"

require "inspec/plugin/v2"
require "inspec/cached_fetcher"
require "plugins/inspec-compliance/lib/inspec-compliance"
require "inspec/dependencies/cache"

describe Inspec::CachedFetcher do
  describe "when original fetcher is Compliance::Fetcher" do
    let(:profiles_result) do
      [{ "name" => "ssh-baseline",
         "title" => "InSpec Profile",
         "maintainer" => "The Authors",
         "copyright" => "The Authors",
         "copyright_email" => "you@example.com",
         "license" => "Apache-2.0",
         "summary" => "An InSpec Compliance Profile",
         "version" => "0.1.1",
         "owner" => "admin",
         "supports" => [],
         "depends" => [],
         "sha256" => "132j1kjdasfasdoaefaewo12312",
         "groups" => [],
         "controls" => [],
         "inputs" => [],
         "latest_version" => "" }]
    end

    before do
      InspecPlugins::Compliance::Configuration.expects(:new).returns({ "token" => "123abc", "server" => "https://a2.instance.com" })

      @stub_get =
        stub_request(
          :get,
          "https://a2.instance.com/owners/admin/compliance/ssh-baseline/tar"
        ).with(
          headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Bearer 123abc",
          "User-Agent" => "Ruby",
          }
        ).to_return(status: 200, body: "", headers: {})
    end

    it "downloads the profile from the compliance service when sha256 not in the cache" do
      prof = profiles_result[0]
      InspecPlugins::Compliance::API.stubs(:profiles).returns(["success", profiles_result])
      cache = Inspec::Cache.new
      entry_path = cache.base_path_for(prof["sha256"])
      mock_fetch = Minitest::Mock.new
      mock_fetch.expect :call, "#{entry_path}.tar.gz", [entry_path]
      cf = Inspec::CachedFetcher.new("compliance://#{prof["owner"]}/#{prof["name"]}", cache)
      cache.stubs(:exists?).with(prof["sha256"]).returns(false)
      cf.fetcher.stub(:fetch, mock_fetch) do
        cf.fetch
      end
      mock_fetch.verify
    end

    it "does not download the profile when the sha256 exists in the inspec cache if version is specified" do
      prof = profiles_result[0]
      InspecPlugins::Compliance::API.stubs(:profiles).returns(["success", profiles_result])
      cache = Inspec::Cache.new
      entry_path = cache.base_path_for(prof["sha256"])
      mock_preferred_entry_for = Minitest::Mock.new
      mock_preferred_entry_for.expect :call, entry_path, [prof["sha256"]]
      cf = Inspec::CachedFetcher.new("compliance://#{prof["owner"]}/#{prof["name"]}#0.1.1", cache)
      cache.stubs(:exists?).with(prof["sha256"]).returns(true)
      cache.stub(:preferred_entry_for, mock_preferred_entry_for) do
        cf.fetch
      end
      mock_preferred_entry_for.verify
      assert_not_requested(@stub_get)
    end

    it "skips caching on compliance if version unspecified" do
      prof = profiles_result[0]
      InspecPlugins::Compliance::API.stubs(:profiles).returns(["success", profiles_result])
      cache = Inspec::Cache.new
      cf = Inspec::CachedFetcher.new("compliance://#{prof["owner"]}/#{prof["name"]}", cache)
      cf.fetch
      assert_requested(@stub_get)
    end
  end
end
