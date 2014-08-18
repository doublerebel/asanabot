Asana = require "asana"
Ajax  = require "awaitajax"


dayAgo = (date) -> date.setDate date.getDate() - 1


class AsanaBot
  taskFields: [
    "id"
    "name"
    "notes"
    "due_on"
    "completed"
    "completed_at"
    "created_at"
    "modified_at"
  ]

  constructor: (@projectId, @interval = 20, @hookUrl, modified_since = 0, @log = console) ->
    @client = Asana.Client.basicAuth process.env.ASANA_API_KEY
    @modified_since = new Date modified_since
    @tasks = []

  start: =>
    return if @running
    @running = true
    @poll()

  poll: (autocb = ->) =>
    await @getTasks defer tasks
    return @again() unless tasks

    unless tasks.length
      @log.log "no new tasks"
      return @again()

    tasks = @sortTasksByRecent tasks
    @modified_since = new Date (new Date tasks[0].created_at).getTime() + 1000

    await @callWebhook tasks, defer err
    @log.error err if err

    @log.log tasks
    @again()

  getTasks: (autocb) =>
    params =
      modified_since: @modified_since.toISOString()
      opt_fields: @taskFields.join ","

    console.log "finding tasks modified since: #{params.modified_since}"
    await (@client.tasks.findByProject @projectId, params).nodeify defer err, tasks
    @log.error err if err
    return tasks

  again: => @timeout = setTimeout @poll, @interval * 1000

  stop: =>
    return @log.error "not running" unless @running
    clearTimeout @timeout
    @running = false

  sortTasksByRecent: (tasks) ->
    tasks.sort (a, b) -> (new Date b.modified_at) - (new Date a.modified_at)

  callWebhook: (data, autocb) ->
    options =
      url: @hookUrl
      data: data
      rejectUnauthorized: false
      dataType: "text/plain"

    @log.log "Posting update of project id: #{@projectId} to: #{@hookUrl}"
    await Ajax.awaitPost options, defer status, xhr, statusText, response
    if status is "error"
      @log.error "error: #{response?.message or status?.message or xhr}"
      @log.error "status: #{statusText}"
      return xhr.statusCode or response

    @log.log "success: #{statusText}"
    null




module.exports = AsanaBot
