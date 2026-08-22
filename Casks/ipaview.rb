cask "ipaview" do
  version "1.3"
  sha256 "TO_BE_SET_BY_RELEASE_WORKFLOW"

  url "https://github.com/everettjf/ipaview/releases/download/v#{version}/IPAView-#{version}.zip"
  name "IPAView"
  desc "Local audit workbench for iOS IPA archives"
  homepage "https://xnu.app/ipaview/"

  depends_on macos: ">= :sonoma"
  app "IPAView.app"

  zap trash: [
    "~/Library/Preferences/com.everettjf.ipaview.plist",
    "~/Library/Saved Application State/com.everettjf.ipaview.savedState",
  ]
end
