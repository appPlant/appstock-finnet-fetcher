# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

set :path, ENV.fetch('APP_HOME', Whenever.path)
set :job_template, "/bin/sh -l -c ':job'"
set :environment_variable, 'APP_ENV'

every :day, at: '11pm' do
  rake 'fetch:stocks drive:upload'
end
