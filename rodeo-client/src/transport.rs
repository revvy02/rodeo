use anyhow::{Context, Result};

use crate::proto;

/// Shared connectrpc transport: host + port + HttpClient + ClientConfig.
/// Every `MasterServiceClient` / `RunServiceClient` created from this uses the
/// same underlying HTTP pool, matching the TS client's "one transport per
/// RodeoClient" model.
#[derive(Clone)]
pub(crate) struct Transport {
    pub host: String,
    pub port: u16,
    http: connectrpc::client::HttpClient,
    config: connectrpc::client::ClientConfig,
}

impl Transport {
    pub fn new(host: impl Into<String>, port: u16) -> Result<Self> {
        let host = host.into();
        let url: http::Uri = format!("http://{host}:{port}")
            .parse()
            .context("invalid server URL")?;
        let http = connectrpc::client::HttpClient::plaintext();
        let config = connectrpc::client::ClientConfig::new(url);
        Ok(Self { host, port, http, config })
    }

    pub fn master(&self) -> proto::MasterServiceClient<connectrpc::client::HttpClient> {
        proto::MasterServiceClient::new(self.http.clone(), self.config.clone())
    }

    pub fn run_service(&self) -> proto::RunServiceClient<connectrpc::client::HttpClient> {
        proto::RunServiceClient::new(self.http.clone(), self.config.clone())
    }
}
