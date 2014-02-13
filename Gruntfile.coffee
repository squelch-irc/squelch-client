module.exports = (grunt) ->

    grunt.task.loadNpmTasks 'grunt-mocha-test'
    grunt.task.loadNpmTasks 'grunt-contrib-coffee'
    grunt.task.loadNpmTasks 'grunt-coffeelint'

    grunt.initConfig
        pkg: 
            grunt.file.readJSON('package.json')

        coffee:
            dist:
                expand: true
                flatten: true
                src: ['src/**/*.coffee']
                dest: 'dist/'
                ext: '.js'

        coffeelint:
            dev:
                src: ['src/**/*.coffee']
            test:
                src: ['test/**/*.coffee']
            options:
                no_tabs: # using tabs!
                    level: 'ignore'
                indentation: # using tabs screws this right up
                    level: 'ignore'
                max_line_length: # I trust you
                    level: 'ignore'

        mochaTest:
            dist:
                options:
                    ui: 'bdd'
                    reporter: 'nyan'
                    require: 'coffee-script/register'
                src:
                    'test/*.coffee'

    grunt.event.on 'coffee.error', (msg) ->
        grunt.log.write msg

    grunt.registerTask 'lint', ['coffeelint']
    grunt.registerTask 'build', ['test', 'coffee:dist']
    grunt.registerTask 'test', ['lint', 'mochaTest']
    grunt.registerTask 'default', ['build']