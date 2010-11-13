# `coke` is a simplified version of [Make](http://www.gnu.org/software/make/)
# ([Rake](http://rake.rubyforge.org/), [Jake](http://github.com/280north/jake))
# for Coco. You define tasks with names and descriptions in a Cokefile,
# and can call them from the command line, or invoke them from other tasks.
#
# Running `coke` with no arguments will print out a list of all the tasks in the
# current directory's Cokefile.

# External dependencies.
fs       = require 'fs'
path     = require 'path'
optparse = require './optparse'
Coco     = require './coco'

# Keep track of the list of defined tasks, the accepted options, and so on.
tasks     = {}
options   = {}
switches  = []
oparse    = null

# Mixin the top-level coke functions for Cakefiles to use directly.
global import

  # Define a coke task with a short name, an optional sentence description,
  # and the function to run as the action itself.
  task: (name, description, action) ->
    [action, description] = [description, action] unless action
    tasks[name] = {name, description, action}

  # Define an option that the Cokefile accepts. The parsed options hash,
  # containing all of the command-line options passed, will be made available
  # as the first argument to the action.
  option: (letter, flag, description) ->
    switches.push [letter, flag, description]

  # Invoke another task in the current Cokefile.
  invoke: (name) ->
    missingTask name unless tasks[name]
    tasks[name].action options

# Run `coke`. Executes all of the tasks you pass, in order. Note that Node's
# asynchrony may cause tasks to execute in a different order than you'd expect.
# If no tasks are passed, print the help screen.
exports.run = ->
  path.exists 'Cokefile', (exists) ->
    throw new Error("Cokefile not found in #{process.cwd()}") unless exists
    args = process.argv.slice 2
    Coco.run fs.readFileSync('Cokefile').toString(), fileName: 'Cokefile'
    oparse  := new optparse.OptionParser switches
    return printTasks() unless args.length
    options := oparse.parse args
    invoke arg for arg of options.arguments

# Display the list of tasks in a format similar to `rake -T`
printTasks = ->
  console.log ''
  width = Math.max (name.length for all name in tasks)...
  pad   = Array(width).join ' '
  for all name, task in tasks
    desc = if task.description then '# ' + task.description else ''
    console.log "coke #{ (name + pad).slice 0, width } #{desc}"
  console.log oparse.help() if switches.length

# Print an error and exit when attempting to all an undefined task.
missingTask = (task) ->
  console.log "No such task: \"#{task}\""
  process.exit 1
