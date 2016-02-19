module.exports = 
    email: ''
    password: ''
    server-name: ''
    log-events: true
    retry-timeout: 5000
    storage-details: 
        * name: \mongo
          connection-string: \mongodb://localhost:27017/reactiflux
          connection-options: 
            auto_reconnect: true
            db:
              w:1
            server:
              socket-options:
                  keepAlive: 1
          insert-into:
            collection: \events
        * name: \redis
          connection-string: \redis://localhost:6379/
          connection-options: {}
          insert-into:
            channel: \reactiflux-events
        ...