use crate::Res;
use crate::Version;
use serde::Deserialize;
use std::path::Path;
use tokio::fs::File;
use tokio::io::AsyncReadExt;

#[derive(Debug, Deserialize)]
struct Data {
    #[serde(rename = "Branch")]
    branch: String,
    // #[serde(rename = "BuildDateStamp")]
    // build_date_stamp: String,
    // #[serde(rename = "BuildId")]
    // build_id: String,
    // #[serde(rename = "BuildTimeStamp")]
    // build_time_stamp: String,
    // #[serde(rename = "Config")]
    // config: String,
    // #[serde(rename = "Platform")]
    // platform: String,
    // #[serde(rename = "RequestedP4ChangeNum")]
    // requested_p4_change_num: String,
    // #[serde(rename = "Shelved_Change")]
    // shelved_change: String,
    // #[serde(rename = "Tag")]
    // tag: String,
    #[serde(rename = "Version")]
    version: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct BuildManifest {
    #[serde(rename = "Data")]
    data: Data,
}

impl BuildManifest {
    pub(crate) fn get_version(&self) -> Version {
        let re = regex::Regex::new(r"(\d+\.\d+\.\d+)").unwrap();
        let branch_ver = re
            .captures(&self.data.branch)
            .unwrap()
            .get(1)
            .unwrap()
            .as_str();
        let build = Version::from_string(&self.data.version).unwrap();
        Version::from_string(&format!("{}.{}", branch_ver, build.build)).unwrap()
    }
    pub(crate) async fn from_file(file: &Path) -> Res<Self> {
        let mut f = File::open(file).await?;
        let mut s = String::new();
        f.read_to_string(&mut s).await?;
        Ok(serde_json::from_str(&s)?)
    }

    pub(crate) async fn is_outdated(&self) -> Res<bool> {
        let xml = reqwest::get("https://status.robertsspaceindustries.com/index.xml")
            .await?
            .bytes()
            .await?;
        let feed = rss::Channel::read_from(&xml[..])?;
        let latest_release = feed
            .items()
            .iter()
            .find(|i| {
                i.title().unwrap_or("") == "[Resolved] Live Deployment" && i.description().is_some()
            })
            .expect("Failed to find latest release from RSS feed");
        if let Some(desc) = latest_release.description() {
            let re = regex::Regex::new(r"(\d+\.\d+\.\d+)-live\.(\d+)").unwrap();
            let matches = re.captures_iter(desc).next().unwrap();
            let latest_version = Version::from_string(&format!("{}.{}", &matches[1], &matches[2]))
                .expect("Failed to parse version");
            let current_version = self.get_version();
            println!(
                "HELPER: Detected latest version is {} and manifest is {}",
                current_version, latest_version
            );
            return Ok(latest_version > self.get_version());
        }
        Ok(false)
    }
}
