dataSource {
    driverClassName = 'org.postgresql.Driver'
    url             = "jdbc:postgresql://${System.getenv('POSTGRESQL_HOST')}:${System.getenv('POSTGRESQL_PORT')}/${System.getenv('POSTGRESQL_DB')}"
    dialect         = 'org.hibernate.dialect.PostgreSQLDialect'
    username        = 'biomart_user'
    password        = 'biomart_user'
    dbCreate        = 'none'
}

hibernate {
    cache.use_second_level_cache = true
    cache.use_query_cache        = true
    cache.provider_class         = 'org.hibernate.cache.EhCacheProvider'
}

environments {
    development {
        dataSource {
            logSql    = true
            formatSql = true
             properties {
                maxActive   = 10
                maxIdle     = 5
                minIdle     = 2
                initialSize = 2
            }
        }
    }
    production {
        dataSource {
            logSql    = false
            formatSql = false
             properties {
                maxActive   = 50
                maxIdle     = 25
                minIdle     = 5
                initialSize = 5
            }
        }
    }
}

// vim: set ts=4 sw=4 et:
