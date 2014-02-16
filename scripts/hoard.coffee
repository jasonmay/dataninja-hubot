# Description:
#   Logs messages to an http server
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Author:
#   jasonmay

{inspect} = require('util')

module.exports = (robot) ->
  request = require('request')
  robot.brain.on 'loaded', =>
    robot.brain.data.savedMessages ||= []
    unless process.env.DATANINJA_PROFILE?
      throw "Profile not defined"
    unless process.env.HOARDER_SERVICE_URL?
      throw "Hoarder URL not defined" unless process.env.HOARDER_SERVICE_URL?

  hoard = (msg, emote) ->
      created = new Date().getTime()
      msgData = {
        nick: msg.message.user.name,
        channel: msg.message.room,
        message: msg.message.text,
        profile: process.env.DATANINJA_PROFILE,
        network: process.env.HUBOT_IRC_SERVER,
        time: created
        params: {}
      }

      robot.logger.debug emote
      if emote is true
        msgData.params.action = true
      robot.logger.debug "Sending: #{inspect msgData}"

      r = request(
        {
          url: "#{process.env.HOARDER_SERVICE_URL}/message/create",
          method: 'post',
          json: msgData
        },
        (err, res) ->
          saved = true
          if err
            robot.logger.warning err
            saved = false
          else
            if res.statusCode isnt 200
              robot.logger.warning "Message post failed: #{res.body}"
              saved = false

          if not saved
            robot.logger.debug "Saving message to redis"
            try
              robot.brain.data.savedMessages.push(msgData)
              robot.logger.debug robot.brain.data.savedMessages
            catch error
              robot.logger.warning error
        )

  robot.hear /./, (msg) ->
    hoard(msg, false)

  # NOTE: hopefully can get something like this in hubot core
  #robot.hearEmote /./, (msg) ->
  #    hoard(msg, true)
