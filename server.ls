require! \body-parser
require! \colors
{http-port}:config = require \./config
DiscordClient = require \discord.io
require! \express
require! \moment
{each, find, group-by, keys, map, Obj, pairs-to-obj, values} = require \prelude-ls
{record} = (require \pipend-spy) config.storage-details

# start-monitoring :: {email :: String, pasword :: String, server-name :: String, log-events :: Boolean ...} -> DiscordBot
start-monitoring = ({email, password, server-name, retry-timeout, log-events}:config) ->

    bot = new DiscordClient {email, password}
        ..connect!
        ..on \ready, (initial-state) ->
            
            console.log 'connected to discord'

            server = find (.name == server-name), (initial-state?.d?.guilds ? [])

            # replaces <#345793485734958> with #channelName
            # fix-message :: String -> String
            fix-message = (message) ->
                bot.fix-message message .replace do 
                    /\<\#(.*?)\>/g
                    (, channel-id) -> 
                        '#' + bot.servers[server.id].channels[channel-id].name
            
            # log :: String -> String -> ()
            log = (color, message) !->
                if log-events
                    current-time = moment!.format "ddd, D MMM YYYY, hh:mm:ss a"
                    console.log colors[color] "[#{current-time}] #{message}"

            # pretty :: object -> String
            pretty = (obj) -> JSON.stringify obj, null, 4

            # record-event :: String -> String -> Int -> String -> object -> p [InsertedEvent]
            record-event = (username, user-id, timestamp, event-type, event-args) ->
                args = {username, user-id, timestamp, event-type, event-args}
                log \gray, "record, #{pretty args}"

                joined-at = bot.servers[server.id].members?[user-id]?.joined_at
                joined-at-timestamp = if !!joined-at then (new Date joined-at .get-time!) else 0
                
                # record event to database(s) using config.storage-details
                result = record do 
                    event-type: event-type
                    event-args: {} <<< event-args <<< 
                        timestamp: timestamp
                        time-delta: timestamp - joined-at-timestamp
                        user-id: user-id
                        username: username
                
                result.then ->
                    log \green, "success, #{pretty args}"

                result.catch (err) ->
                    log \red, "err, #{pretty args}, #{err.to-string!}"


            bot.on \message, (username, user-id, channel-id, message, raw-event) ->
                if (bot.server-from-channel channel-id) == server.id
                    record-event do 
                        username
                        user-id
                        new Date raw-event?.d?.timestamp .get-time!
                        \message
                        channel-name: bot.servers[server.id].channels[channel-id].name
                        mentions: raw-event?.d?.mentions |> map (.username)
                        mention-everyone: raw-event?.d?.mention_everyone
                        message-id: raw-event?.d?.id
                        message: fix-message message

            bot.on \debug, (raw-event) ->
                if raw-event.d.guild_id == server.id
                    switch raw-event.t
                    | \GUILD_MEMBER_ADD \GUILD_MEMBER_REMOVE =>
                        {user} = raw-event.d
                        record-event do 
                            user.username
                            user.id
                            new Date raw-event?.d?.joined_at .get-time!
                            if raw-event.t == \GUILD_MEMBER_ADD then \new-user else \left-community
                            {}

                if raw-event.t == \MESSAGE_UPDATE and server.id == (bot.server-from-channel raw-event.d.channel_id)
                    {author, content, channel_id, timestamp, mentions, mention_everyone}? = raw-event?.d
                    record-event do 
                        author?.username
                        author?.id
                        new Date timestamp .get-time!
                        \messageUpdate
                        channel-name: bot.servers[server.id].channels[channel_id].name
                        mentions: (mentions ? []) |> map (.username)
                        mention-everyone: mention_everyone
                        message-id: raw-event?.d?.id
                        message: fix-message content

            bot.on \presence, (username, user-id, status, game-name, raw-event) ->
                if raw-event.d.guild_id == server.id
                    record-event do 
                        username
                        user-id
                        Date.now!
                        \presence
                        status: status
                        game-id: raw-event.d.game_id
                        game-name: game-name

            # try to reconnect on disconnect
            bot.on \disconnected, ->
                console.log \disconnected, arguments
                <- set-timeout _, retry-timeout
                start-monitoring config
    bot

bot = start-monitoring config

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs
    ..use body-parser.json!
    ..use body-parser.urlencoded {extended: false}
    ..use \/node_modules, express.static "#__dirname/node_modules"
    ..use \/public, express.static "#__dirname/public"

(require \./routes) bot
    |> each ([, method]:route) -> app[method].apply app, route.slice 2

app.listen http-port
console.log "Started listening on port #{http-port}"



