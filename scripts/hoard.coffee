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

url         = require('url')
querystring = require('querystring')
request     = require('request')
{inspect}   = require('util')

unless process.env.DATANINJA_PROFILE?
  throw "Profile not defined"
unless process.env.HOARDER_SERVICE_URL?
  throw "Hoarder URL not defined" unless process.env.HOARDER_SERVICE_URL?

module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.savedMessages ||= []
    if robot.brain.data.savedMessages.length > 0
      request(
        {
          method: "get",
          url: "#{process.env.HOARDER_SERVICE_URL}/health.json"
        },
        (err, res) ->
          if err
            robot.logger.warning "Hoarder not found!"
          else
            savedMessages = robot.brain.data.savedMessages
            robot.logger.debug "Saved messages: #{inspect savedMessages}"
            if savedMessages and savedMessages.length > 0
              robot.brain.data.savedMessages = []
              # if any of them fail they will end up back in
              # the brain regardless, so it's safe to clear out
              # ahead of time
              for msgData in savedMessages
                robot.logger.debug "Unqueuing and posting: #{inspect msgData}"
                postToHoarder msgData
      )

  postToHoarder = (msgData) ->
      request(
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
      postToHoarder msgData


  robot.hear /./, (msg) ->
    hoard(msg, false)

  robot.router.get("/hubot/hoarder", (req, res) ->
    query = querystring.parse(url.parse(req.url).query)

    body = ""
    if query.b is "up"
      savedMessages = robot.brain.data.savedMessages
      robot.logger.debug "Saved messages: #{inspect savedMessages}"
      if savedMessages and savedMessages.length > 0
        robot.brain.data.savedMessages = []
        # if any of them fail they will end up back in
        # the brain regardless, so it's safe to clear out
        # ahead of time
        for msgData in savedMessages
          robot.logger.debug "Unqueuing and posting: #{inspect msgData}"
          postToHoarder msgData
        body = "OK"

    res.end body
  )

  # NOTE: hopefully can get something like this in hubot core
  # robot.hearEmote /./, (msg) ->
  #    hoard(msg, true)
