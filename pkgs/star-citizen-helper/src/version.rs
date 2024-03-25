#[derive(Debug, PartialEq, PartialOrd)]
pub(crate) struct Version {
    major: u32,
    minor: u32,
    patch: u32,
    pub build: u32,
}

impl Version {
    pub(crate) fn to_string(&self) -> String {
        format!(
            "{}.{}.{}.{}",
            self.major, self.minor, self.patch, self.build
        )
    }
    pub(crate) fn from_string(version_string: &str) -> Option<Version> {
        let parts: Vec<&str> = version_string.split('.').collect();
        if parts.len() != 4 {
            return None;
        }

        let major = parts[0].parse().ok()?;
        let minor = parts[1].parse().ok()?;
        let patch = parts[2].parse().ok()?;
        let build = parts[3].parse().ok()?;

        Some(Version {
            major,
            minor,
            patch,
            build,
        })
    }
}
