require! \./config
DiscordClient = require \discord.io
{find, group-by, keys, map, Obj, pairs-to-obj, values} = require \prelude-ls
{record} = (require \pipend-spy) config.storage-details

start-monitoring = ({email, password, server-name, retry-timeout}:config) ->

    bot = new DiscordClient {email, password}
        ..connect!
        ..on \ready, (initial-state) ->
            
            console.log 'connected to discord'

            server = find (.name == server-name), (initial-state?.d?.guilds ? [])

            # fix-message :: String -> String
            fix-message = (message) ->
                bot.fix-message message .replace /\<\#(.*?)\>/g, (, channel-id) -> '#' + bot.servers[server.id].channels[channel-id].name                
            
            # record-chat-event :: String -> String -> Int -> String -> object -> Void
            record-chat-event = (username, user-id, timestamp, event-type, event-args) !->
                record do
                    event-type: event-type
                    event-args: {} <<< event-args <<< 
                        timestamp: timestamp
                        time-delta: timestamp - (new Date bot.servers[server.id].members[user-id].joined_at .get-time!)
                        user-id: user-id
                        username: username

            bot.on \message, (username, user-id, channel-id, message, raw-event) ->
                if (bot.server-from-channel channel-id) == server.id
                    record-chat-event do 
                        username
                        user-id
                        new Date raw-event?.d?.timestamp .get-time!
                        \message
                        channel-name: bot.servers[server.id].channels[channel-id].name
                        mentions: raw-event?.d?.mentions |> map (.username)
                        mention-everyone: raw-event?.d?.mention_everyone
                        message: fix-message message

            bot.on \debug, (raw-event) ->
                if raw-event.t == \GUILD_MEMBER_ADD and raw-event.d.guild_id == server.id
                    {user} = raw-event.d
                    record-chat-event do 
                        user.username
                        user.id
                        new Date raw-event?.d?.joined_at .get-time!
                        \new-user
                        {}

            bot.on \presence, (username, user-id, status, raw-event) ->
                if raw-event.d.guild_id == server.id
                    record-chat-event do 
                        username
                        user-id
                        Date.now!
                        \presence
                        status: status
                        game-id: raw-event.d.game_id

            # try to reconnect on disconnect
            bot.on \disconnect, ->
                console.log \disconnected, arguments
                clear-interval interval
                <- set-timeout _, retry-timeout
                start-monitoring config

start-monitoring config

