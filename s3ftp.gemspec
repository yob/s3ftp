lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |spec|
  spec.name = "s3ftp"
  spec.version = "0.0.2"
  spec.summary = "An FTP proxy in front of an Amazon S3 bucket"
  spec.description = "Run an FTP server that persists all data to an Amazon S3 bucket"
  #spec.files =  Dir.glob("{bin,lib}/**/**/*") + ["Gemfile", "README.markdown","MIT-LICENSE"]
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w{README.markdown MIT-LICENSE }
  spec.rdoc_options << '--title' << 'S3-FTP Documentation' <<
                       '--main'  << 'README.markdown' << '-q'
  spec.authors = ["James Healy"]
  spec.email   = ["jimmy@deefa.com"]
  spec.homepage = "http://github.com/yob/s3ftp"
  spec.required_ruby_version = ">=1.9.2"

  spec.add_development_dependency("rake")
  spec.add_development_dependency("rspec", "~>2.6")

  spec.add_dependency('em-ftpd')
  spec.add_dependency('happening')
  spec.add_dependency('nokogiri')
  spec.add_dependency('trollop')
  spec.add_dependency('bcrypt-ruby')
  spec.executables = ["s3ftp"]
  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables = ["s3ftp"]
  spec.require_path = 'lib'
end
