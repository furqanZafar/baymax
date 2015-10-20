require! \./config
DiscordClient = require \discord.io
{find, group-by, keys, map, Obj, pairs-to-obj, values} = require \prelude-ls
{record} = (require \pipend-spy) config.storage-details

start-monitoring = ({email, password, server-name, retry-timeout}:config) ->

    bot = new DiscordClient {email, password}
        ..connect!
        ..on \ready, ->
            
            console.log 'connected to discord'

            server = find (.name == server-name), (it?.d?.guilds ? [])

            # channels-hash :: Map channel-id :: String, {name :: String, topic :: String}
            channels-hash = server.channels
                |> map ({id, name, topic}) -> [id, {name, topic}]
                |> pairs-to-obj
            
            bot.on \message, (user, user-id, channel-id, message, raw-event) ->

                # return if the user does not belong to any configured channels
                return if !channels-hash?[channel-id]

                event-args = 
                    timestamp: new Date raw-event?.d?.timestamp .get-time!
                    channel-name: channels-hash[channel-id].name
                    username: user
                    mentions: raw-event?.d?.mentions |> map (.username)
                    message: message

                record do 
                    event-type: \message
                    event-args: event-args

            bot.on \debug, (raw-event) ->
                if raw-event.t == \GUILD_MEMBER_ADD and raw-event.d.guild_id == server.id
                    record do 
                        event-type: \new-user
                        event-args: 
                            timestamp: new Date raw-event?.d?.joined_at .get-time!
                            username: raw-event.d.user.username

            bot.on \presence, (user, user-id, status, raw-event) ->
                if raw-event.d.guild_id == server.id
                    record do 
                        event-type: \presence
                        event-args:
                            timestamp: Date.now!
                            username: user
                            status: status

            # try to reconnect on disconnect
            bot.on \disconnect, ->
                console.log \disconnected, arguments
                clear-interval interval
                <- set-timeout _, retry-timeout
                start-monitoring config


start-monitoring config
