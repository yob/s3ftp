# coding: utf-8

module S3FTP
  class Driver

    USER  = 0
    PASS  = 1
    ADMIN = 2

    def initialize(config, passwd)
      @config = config
      @users  = {}
      CSV.parse(passwd).map { |row|
        @users[row[USER]] = {
          :pass  => row[PASS],
          :admin => row[ADMIN].to_s.upcase == "Y"
        }
      }
    end

    def change_dir(user, path, &block)
      prefix = scoped_path(user, path)

      item = Happening::S3::Bucket.new(aws_bucket, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        yield contains_directory?(response.response, prefix)
      end
    end

    def dir_contents(user, path, &block)
      prefix = scoped_path_with_trailing_slash(user,path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response_header["CONTENT_LENGTH"].to_i }

      item = Happening::S3::Bucket.new(aws_bucket, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret, :prefix => prefix, :delimiter => "/")
      item.get do |response|
        yield parse_bucket_list(response.response)
      end
    end

    def authenticate(user, pass, &block)
      yield @users[user] && @users[user][:pass] == pass
    end

    def bytes(user, path, &block)
      key = scoped_path(user, path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response_header["CONTENT_LENGTH"].to_i }

      item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.head(:retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def get_file(user, path, &block)
      key = scoped_path(user, path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield response.response }

      item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.get(:retry_count => 1, :on_success => on_success, :on_error => on_error)
    end

    def put_file(user, path, data, &block)
      key = scoped_path(user, path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.put(data, :retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    def delete_file(user, path, &block)
      key = scoped_path(user, path)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.delete(:retry_count => 1, :on_success => on_success, :on_error => on_error)
    end

    def delete_dir(user, path, &block)
      prefix = scoped_path(user, path)

      on_error   = Proc.new {|response| yield false }

      item = Happening::S3::Bucket.new(aws_bucket, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret, :prefix => prefix)
      item.get(:on_error => on_error) do |response|
        keys = bucket_list_to_full_keys(response.response)
        delete_object = Proc.new { |key, iter|
          item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
          item.delete(:retry_count => 1, :on_error => on_error) do |response|
            iter.next
          end
        }
        on_complete = Proc.new { yield true }

        EM::Iterator.new(keys, 5).each(delete_object, on_complete)
      end
    end

    def rename(user, from, to, &block)
      source_key = scoped_path(user, from)
      source_obj = aws_bucket + "/" + source_key
      dest_key   = scoped_path(user, to)

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(aws_bucket, dest_key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.put(nil, :retry_count => 1, :on_error => on_error, :headers => {"x-amz-copy-source" => source_obj}) do |response|
        item = Happening::S3::Item.new(aws_bucket, source_key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
        item.delete(:retry_count => 1, :on_success => on_success, :on_error => on_error)
      end
    end

    def make_dir(user, path, &block)
      key = scoped_path(user, path) + "/.dir"

      on_error   = Proc.new {|response| yield false }
      on_success = Proc.new {|response| yield true  }

      item = Happening::S3::Item.new(aws_bucket, key, :aws_access_key_id => aws_key, :aws_secret_access_key => aws_secret)
      item.put("", :retry_count => 0, :on_success => on_success, :on_error => on_error)
    end

    private

    def admin?(user)
      @users[user] && @users[user][:admin]
    end

    def scoped_path_with_trailing_slash(user,path)
      path  = scoped_path(user,path)
      path += "/" if path[-1,1] != "/"
      path == "/" ? nil : path
    end

    def scoped_path(user,path)
      path = "" if path == "/"

      if admin?(user)
        File.join("/", path)[1,1024]
      else
        File.join("/", user, path)[1,1024]
      end
    end

    def aws_bucket
      @config[:bucket]
    end

    def aws_key
      @config[:aws_key]
    end

    def aws_secret
      @config[:aws_secret]
    end

    def bucket_list_to_full_keys(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      doc.xpath('//Contents').map { |node|
        node.xpath('./Key').first.content
      }
    end

    def contains_directory?(xml, path)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      prefix = doc.xpath('/ListBucketResult/Prefix').first.content

      doc.xpath('//CommonPrefixes').any? { |node|
        name  = node.xpath('./Prefix').first.content

        name.to_s.start_with?(prefix)
      }
    end

    def parse_bucket_list(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      prefix = doc.xpath('/ListBucketResult/Prefix').first.content
      files = doc.xpath('//Contents').select { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content.to_i
        name != prefix && bytes > 0
      }.map { |node|
        name  = node.xpath('./Key').first.content
        bytes = node.xpath('./Size').first.content
        file_item(name[prefix.size, 1024], bytes)
      }
      dirs = doc.xpath('//CommonPrefixes').select { |node|
        node.xpath('./Prefix').first.content != prefix + "/"
      }.map { |node|
        name  = node.xpath('./Prefix').first.content
        dir_item(name[prefix.size, 1024].tr("/",""))
      }
      default_dirs + dirs + files
    end

    def default_dirs
      [dir_item("."), dir_item("..")]
    end

    def dir_item(name)
      EM::FTPD::DirectoryItem.new(:name => name, :directory => true, :size => 0)
    end

    def file_item(name, bytes)
      EM::FTPD::DirectoryItem.new(:name => name, :directory => false, :size => bytes)
    end

  end
end
