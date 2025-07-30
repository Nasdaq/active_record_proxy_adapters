## [Unreleased]

## [0.7.0] - 2025-07-30

- Add support for configuring a Context API [1865e65](https://github.com/Nasdaq/active_record_proxy_adapters/commit/1865e65dff9f5e53b36e0795a29c32400315a266)
- Add Rack middleware to store context in session [1bf2b60](https://github.com/Nasdaq/active_record_proxy_adapters/commit/1bf2b6099cbec9b4a362e3d0cb7deb8d2ca5d804)
- Allow separate configuration blocks per database name [4325b0](https://github.com/Nasdaq/active_record_proxy_adapters/commit/4325b09c68fa4f00243a97e790d2d21ef92fc521)

## [0.6.2, 0.5.2, 0.4.8] - 2025-07-21

- Fix Hijackable methods for ActiveRecord 7.1 or greater [97c5dbc](https://github.com/Nasdaq/active_record_proxy_adapters/commit/97c5dbc46ad9ab19ecc21d16cdc79fcea4158378)

## [0.6.1, 0.5.1, 0.4.7] - 2025-06-27

- Bypass proxy when opening a transaction in ActiveRecord 7.0.x [d03adf6](https://github.com/Nasdaq/active_record_proxy_adapters/commit/d03adf61e284cc29f82879aefc4f087a91e01d33)

## [0.6.0] - 2025-06-16

- Add optional support for caching SQL pattern matching [c1f6ff9](https://github.com/Nasdaq/active_record_proxy_adapters/commit/c1f6ff9bb211b1e7b8fea4b138e4c13fb6378cbe)

## [0.5.0] - 2025-05-22

- Add SQLite3ProxyAdapter [e9bb853](https://github.com/Nasdaq/active_record_proxy_adapters/commit/e9bb8536123ee7c14960bf802d43be4c7ce6d1ee)

## [0.4.6, 0.3.6] - 2025-04-28

- Fix loading of non PostgreSQL adapters [1bf5ee9](https://github.com/Nasdaq/active_record_proxy_adapters/commit/1bf5ee9c6a21cb81d928e82b988c0a6e79ff878b)

## [0.4.5, 0.3.5, 0.2.6, 0.1.9] - 2025-03-31

- Fix CTEs for a write being wrongly sent to the replica [551204e](https://github.com/Nasdaq/active_record_proxy_adapters/commit/551204e7a9beec4ce920268bb95203498f49ec61)

## [0.4.4, 0.3.4, 0.2.5, 0.1.8] - 2025-03-19

- Fix ActiveRecord 8 hijacked methods [bef1de4](https://github.com/Nasdaq/active_record_proxy_adapters/commit/bef1de414dbe7c523c32d3f4bce1b266ab3286f1)
- Add Rails 8.0.2 compatibility [f3b2d8c](https://github.com/Nasdaq/active_record_proxy_adapters/commit/f3b2d8c2da266cc5ab4d0e5fe5a8c04d589b661e)

## [0.4.3, 0.3.3, 0.2.4, 0.1.7] - 2025-03-03

- Call verify! on primary connection before running any query against it [0c9bafe](https://github.com/Nasdaq/active_record_proxy_adapters/commit/0c9bafe363280ce32db25e08756e7ff6395c5c91)
- Stick to primary when verifying connection from the pool [00acbac](https://github.com/Nasdaq/active_record_proxy_adapters/commit/00acbacb93a825bb700fdd4901a5b42568236ca2)

## [0.4.2, 0.3.2, 0.2.3, 0.1.6] - 2025-02-25

- Trim down gem size by preventing unnecessary files from packing [6638d26](https://github.com/Nasdaq/active_record_proxy_adapters/commit/6638d26c1e0ff299ac9882caf3953e3572f4668d)

## [0.4.1] - 2025-02-24

- Pack gem without appraisals

## [0.4.0] - 2025-02-24

- Add load hooks for proxy adapters
- Add TrilogyProxyAdapter
- Add Ruby 3.4 to test matrix

## [0.3.1] - 2025-02-12
- Fix Active Record adapters dependency loading [b729f8b](https://github.com/Nasdaq/active_record_proxy_adapters/commit/b729f8bdb517cdc80f348c00e1fe4c5b56b76143)

## [0.3.0] - 2025-01-17

- Add Mysql2ProxyAdapter [7481b79](https://github.com/Nasdaq/active_record_proxy_adapters/commit/7481b79dc93114f9b3b40faa8f3eecce90fe9104)

## [0.2.2, 0.1.5] - 2025-01-02

- Handle PendingMigrationConnection introduced by Rails 7.2 and backported to Rails 7.1 [7935626](https://github.com/Nasdaq/active_record_proxy_adapters/commit/793562694c05d554bad6e14637b34e5f9ffd2fc5)
- Stick to same connection throughout request span [789742f](https://github.com/Nasdaq/active_record_proxy_adapters/commit/789742fd7a33ecd555a995e8a1e1336455caec75)

## [0.2.1] - 2025-01-02

- Fix replica connection pool getter when specific connection name is not found [847e150](https://github.com/Nasdaq/active_record_proxy_adapters/commit/847e150dd21c5bc619745ee1d9d8fcaa9b8f2eea)

## [0.2.0] - 2024-12-24

- Add custom log subscriber to tag queries based on the adapter being used [68b8c1f](https://github.com/Nasdaq/active_record_proxy_adapters/commit/68b8c1f4191388eb957bf12e0f84289da667e940)

## [0.1.4] - 2025-01-02

- Fix replica connection pool getter when specific connection name is not found [88b32a2](https://github.com/Nasdaq/active_record_proxy_adapters/commit/88b32a282b54d420e652f638656dbcf063ac8796)

## [0.1.3] - 2024-12-24

- Fix replica connection pool getter when database configurations have multiple replicas [ea5a339](https://github.com/Nasdaq/active_record_proxy_adapters/commit/ea5a33997da45ac073f166b3fbd2d12426053cd6)
- Retrieve replica pool without checking out a connection [6470ef5](https://github.com/Nasdaq/active_record_proxy_adapters/commit/6470ef58e851082ae1f7a860ecdb5b451ef903c8)

## [0.1.2] - 2024-12-16

- Fix CTE regex matcher [4b1d10b](https://github.com/Nasdaq/active_record_proxy_adapters/commit/4b1d10bfd952fb1f5b102de8cc1a5bd05d25f5e9)

## [0.1.1] - 2024-11-27

- Enable RubyGems MFA [2a71b1f](https://github.com/Nasdaq/active_record_proxy_adapters/commit/2a71b1f4354fb966cc0aa68231ca5837814e07ee)

## [0.1.0] - 2024-11-19

- Add PostgreSQLProxyAdapter [2b3bb9f](https://github.com/Nasdaq/active_record_proxy_adapters/commit/2b3bb9f7359139519b32af3018ceb07fed8c6b33)

## [0.1.0.rc2] - 2024-10-28

- Add PostgreSQLProxyAdapter [2b3bb9f](https://github.com/Nasdaq/active_record_proxy_adapters/commit/2b3bb9f7359139519b32af3018ceb07fed8c6b33)
