use tokio::fs;

type Res<T> = Result<T, Box<dyn std::error::Error>>;

mod build_manifest;
mod version;
use build_manifest::BuildManifest;
use std::path::Path;
use version::Version;

#[tokio::main]
async fn main() -> Res<()> {
    let wine_prefix = std::path::PathBuf::from(std::env::var("WINEPREFIX")?);
    let user = std::env::var("USER")?;
    let build_manifest = wine_prefix
        .join("drive_c/Program Files/Roberts Space Industries/StarCitizen/LIVE/build_manifest.id");
    let appdata_dir = wine_prefix
        .join("drive_c/users")
        .join(user)
        .join("AppData/Local/Star Citizen");
    let build: BuildManifest = BuildManifest::from_file(&build_manifest).await?;
    if build.is_outdated().await? {
        if !zenity_prompt(
            "Update detected, do you want to remove shader cache? (Recommended)",
            "Star Citizen Helper",
        )
        .await
        {
            println!("Aborted");
            return Ok(());
        }
        clean_shader_cache(&appdata_dir).await?;
    }
    Ok(())
}

async fn clean_shader_cache(appdata_dir: &Path) -> Res<()> {
    if let Ok(mut entries) = fs::read_dir(&appdata_dir).await {
        while let Some(entry) = entries.next_entry().await.unwrap_or(None) {
            let datadir = entry.path().join("shaders");
            if let Ok(metadata) = fs::metadata(&datadir).await {
                if metadata.is_dir() {
                    println!("Deleting {:?}", datadir);
                    if let Err(err) = fs::remove_dir_all(&datadir).await {
                        println!("Error deleting {:?}: {}", datadir, err);
                    }
                }
            }
        }
    } else {
        println!(
            "Error: Failed to read directories in {}",
            appdata_dir.display()
        );
    }
    Ok(())
}

async fn zenity_prompt(message: &str, title: &str) -> bool {
    let output = tokio::process::Command::new("zenity")
        .arg("--question")
        .arg("--text")
        .arg(message)
        .arg("--title")
        .arg(title)
        .output()
        .await
        .expect("Failed to execute zenity");

    output.status.success()
}
