Fs = require 'fs'
Path = require 'path'

HUBOT_DOCUMENTATION_SECTIONS = [
  'description'
  'dependencies'
  'configuration'
  'commands'
  'notes'
  'author'
  'examples'
  'urls'
]

class Scripts
  # Loads scripts and manages their documentation.
  #
  # robot - A instance of the Robot class.
  constructor: (@robot) ->
    @commands = []

    @robot.adapter.once 'connected', =>
      scriptPaths = [
        Path.resolve('.', 'scripts')
        Path.resolve('.', 'src', 'scripts')
      ]

      @load path for path in scriptPaths
      @parseHubotScripts Path.resolve('.', 'hubot-scripts.json')
      @parseExternalScripts Path.resolve('.', 'external-scripts.json')

  # Public: Parse hubot-scripts.json and load specified scripts.
  #
  # path - A String path to the hubot-scripts.json file.
  #
  # Returns nothing.
  parseHubotScripts: (path) ->
    return unless Fs.existsSync path

    Fs.readFile path, (err, data) =>
      if err?
        @robot.logger.error "Unable to read hubot-scripts.json:\n" +
          "#{err.stack}"
        process.exit 1

      try
        return if data.length is 0

        scripts = JSON.parse(data)
        scriptsPath = Path.resolve(
          'node_modules',
          'hubot-scripts',
          'src',
          'scripts'
        )
        @loadHubotScripts scriptsPath, scripts
      catch err
        @robot.logger.error "Unable to parse hubot-scripts JSON:\n" +
          "#{err.stack}"
        process.exit 1

  # Public: Parse external-scripts.json and load specified packages.
  #
  # path - A String path to the external-scripts.json file.
  #
  # Returns nothing.
  parseExternalScripts: (path) ->
    return unless Fs.existsSync path

    Fs.readFile path, (err, data) =>
      if err?
        @robot.logger.error "Unable to read external-scripts.json:\n" +
          "#{err.stack}"
        process.exit 1

      try
        return if data.length is 0
        packages = JSON.parse(data)
        @loadExternalScripts packages
      catch err
        @robot.logger.error "Unable to parse external-scripts JSON:\n" +
          "#{err.stack}"
        process.exit 1

  # Public: Loads every script in the given path.
  #
  # path - A String path on the filesystem.
  #
  # Returns nothing.
  load: (path) ->
    @robot.logger.debug "Loading scripts from #{path}"
    Fs.exists path, (exists) =>
      if exists
        @loadFile path, file for file in Fs.readdirSync(path)

  # Public: Loads a file in path.
  #
  # path - A String path on the filesystem.
  # file - A String filename in path on the filesystem.
  #
  # Returns nothing.
  loadFile: (path, file) ->
    ext = Path.extname file
    full = Path.join path, Path.basename(file, ext)
    if ext is '.coffee' or ext is '.js'
      try
        require(full) @robot
        @parseHelp "#{path}/#{file}"
      catch err
        @robot.logger.error "Unable to load #{full}:\n#{err.stack}"
        process.exit 1

  # Public: Load scripts specfied in the `hubot-scripts.json` file.
  #
  # path    - A String path to the hubot-scripts files.
  # scripts - An Array of scripts to load.
  #
  # Returns nothing.
  loadHubotScripts: (path, scripts) ->
    @robot.logger.debug "Loading hubot-scripts from #{path}"
    @loadFile path, script for script in scripts

  # Public: Load scripts from packages specfied in the
  # `external-scripts.json` file.
  #
  # packages - An Array of packages containing hubot scripts to load.
  #
  # Returns nothing.
  loadExternalScripts: (packages) ->
    @robot.logger.debug "Loading external-scripts from npm packages"
    for pkg in packages
      try
        require(pkg) @robot
      catch err
        @robot.logger.error "Error loading scripts from npm package:\n" +
          "#{err.stack}"
        process.exit 1

  # Load help info from a loaded script.
  #
  # path - A String path to the file on disk.
  #
  # Returns nothing.
  parseHelp: (path) ->
    @robot.logger.debug "Parsing help for #{path}"
    scriptName = Path.basename(path).replace(/\.(coffee|js)$/, '')

    Fs.readFile path, 'utf-8', (err, body) =>
      if err?
        @robot.logger.error "Error parsing help:\n#{err.stack}"
        process.exit 1

      currentSection = null

      for line in body.split("\n")
        break unless line[0] is '#' or line.substr(0, 2) is '//'

        cleaned = line.replace(/^(#|\/\/)\s?/, "").trim()
        continue if cleaned.length is 0 or cleaned.toLowerCase() is 'none'
        nextSection = cleaned.toLowerCase().replace(':', '')

        if nextSection in HUBOT_DOCUMENTATION_SECTIONS
          currentSection = nextSection
        else
          if currentSection? and currentSection is 'commands'
            @commands.push cleaned.trim()

  # Public: Get a sorted Array of hubot commands with descriptions.
  #
  # Returns an Array of sorted hubot commands with descriptions.
  helpCommands: ->
    @commands.sort()

module.exports = Scripts
