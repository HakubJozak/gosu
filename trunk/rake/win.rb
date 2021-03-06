namespace :win do
  WINDOWS_ARCHIVE_FILENAME = "public/gosu-windows-#{GOSU_VERSION}.zip"
  
  desc "Build the archive #{WINDOWS_ARCHIVE_FILENAME}"
  task :archive => [:version] do
    files = COMMON_CPP_FILES + FileList['Gosu/*.hpp', 'lib/Gosu.lib', 'lib/GosuDebug.lib', 'lib/fmod.dll']
    sh "zip #{WINDOWS_ARCHIVE_FILENAME} #{files.map { |filename| "'#{filename}'" }.join(' ')}"
  end

  desc "Releases the archive #{WINDOWS_ARCHIVE_FILENAME} on GoogleCode"
  task :release => :archive do
    sh "./googlecode_upload.py --summary=\"Gosu #{GOSU_VERSION}, compiled for 32-bit Windows (C++)\"" +
       " --project=gosu --user=julianraschke --labels=\"Featured,Type-Archive,OpSys-Windows\" #{WINDOWS_ARCHIVE_FILENAME}"
  end

  task :gem => [:version]

  WINDOWS_SPEC = Gem::Specification.new do |s|
    apply_gemspec_defaults s
    s.platform = 'i386-mingw32'#'x86-mswin32-60' ...you can always force the gem platform
    s.files = COMMON_RUBY_FILES + ['lib/gosu.for_1_8.so', 'lib/gosu.for_1_9.so', 'lib/fmod.dll']
  end
  Rake::GemPackageTask.new(WINDOWS_SPEC) { |t| t.package_dir = 'public' }
  
  task :release_gem => :gem do
    sh "gem push public/gosu-#{GOSU_VERSION}-x86-mingw32.gem"
  end
end
