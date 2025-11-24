mod connection;
mod manager;
mod types;
mod worker;

pub use manager::{Manager, ManagerError};
// Re-exports removed - types used internally only
