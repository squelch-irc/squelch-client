module.exports = (grunt) ->

    grunt.task.loadNpmTasks 'grunt-mocha-test'
    grunt.task.loadNpmTasks 'grunt-contrib-coffee'
    grunt.task.loadNpmTasks 'grunt-contrib-clean'
    grunt.task.loadNpmTasks 'grunt-coffeelint'

    grunt.initConfig
        pkg:
            grunt.file.readJSON('package.json')

        coffee:
            dist:
                expand: true
                flatten: false
                cwd: 'src'
                src: ['**/*.coffee']
                dest: 'dist/'
                ext: '.js'

        clean:
            files: 'dist/'

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
                arrow_spacing:
                    level: 'warn'
                colon_assignment_spacing:
                    level: 'warn'
                    spacing:
                        left: 0
                        right: 1
                no_unnecessary_double_quotes:
                    level: 'warn'


        mochaTest:
            dist:
                options:
                    ui: 'bdd'
                    reporter: 'spec'
                    require: 'coffee-script/register'
                src:
                    'test/*.coffee'

    grunt.event.on 'coffee.error', (msg) ->
        grunt.log.write msg

    grunt.registerTask 'lint', ['coffeelint']
    grunt.registerTask 'build', ['test', 'clean', 'coffee:dist']
    grunt.registerTask 'test', ['lint', 'mochaTest']
    grunt.registerTask 'default', ['build']
