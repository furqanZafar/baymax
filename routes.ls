{server-name}? = require \./config.ls
{find, map, obj-to-pairs} = require \prelude-ls

# :: DiscordBot -> [ExpressRoutes]
module.exports = (bot) ->
    routes = 
        * 'channels-list', 'get', '/api/channels', (req, res) -> 
            res.send do 
                bot.servers
                    |> obj-to-pairs
                    |> find (.1.name == server-name)
                    |> (.1.channels)
                    |> obj-to-pairs
                    |> map ([channel-id, channel]) -> {} <<< channel <<< {channel_id: channel-id}
        ...