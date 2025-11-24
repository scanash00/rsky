use crate::APP_USER_AGENT;
use anyhow::Result;
use futures::stream::{self, StreamExt};
use rsky_common::time::MINUTE;
use std::time::SystemTime;

const NOTIFY_THRESHOLD: i32 = 20 * MINUTE; // 20 minutes;

#[derive(Debug, Clone)]
pub struct Crawlers {
    pub hostname: String,
    pub crawlers: Vec<String>,
    pub last_notified: usize,
}

#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct CrawlerRequest {
    pub hostname: String,
}

impl Crawlers {
    pub fn new(hostname: String, crawlers: Vec<String>) -> Self {
        Crawlers {
            hostname,
            crawlers,
            last_notified: 0,
        }
    }

    pub async fn notify_of_update(&mut self) -> Result<()> {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .expect("timestamp in micros since UNIX epoch")
            .as_micros() as usize;
        let hostname = self.hostname.clone();
        let _ = stream::iter(self.crawlers.clone())
            .then(|service: String| {
                let hostname = hostname.clone();
                async move {
                    let client = reqwest::Client::builder()
                        .user_agent(APP_USER_AGENT)
                        .build()?;
                    let record = CrawlerRequest {
                        hostname,
                    };
                    let url = format!("{}/xrpc/com.atproto.sync.requestCrawl", service);
                    tracing::info!("Sending crawl request to {}", url);
                    let resp = client
                        .post(&url)
                        .json(&record)
                        .send()
                        .await?;
                    tracing::info!("Crawl request to {} returned status: {}", url, resp.status());
                    Ok::<reqwest::Response, anyhow::Error>(resp)
                }
            })
            .collect::<Vec<_>>()
            .await
            .into_iter()
            .collect::<Result<Vec<_>, _>>()?;

        self.last_notified = now;
        Ok(())
    }
}
