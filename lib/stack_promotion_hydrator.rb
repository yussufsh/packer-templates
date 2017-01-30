require 'json'
require 'logger'
require 'pathname'

class StackPromotionHydrator
  def initialize(
    stack_promotion: nil,
    output_dir: '.'
  )
    @stack_promotion = stack_promotion
    @output_dir = Pathname.new(output_dir).expand_path
  end

  attr_reader :stack_promotion, :output_dir

  def hydrate!
    output_dir.mkpath

    create_file_diffs
    create_env_diff
    create_index_files
  end

  private def create_file_diffs
    %w(
      dpkg-manifest.json
      job-board-register.yml
      node-attributes.yml
      system_info.json
      travis_packer_templates_rspec.json
    ).each do |metadata_file|
      next unless stack_promotion.cur.metadata.files.key?(metadata_file) &&
                  stack_promotion.nxt.metadata.files.key?(metadata_file)
      if metadata_file == 'travis_packer_templates_rspec.json'
        munge_rspec_json([
                           stack_promotion.cur.metadata.files[metadata_file],
                           stack_promotion.nxt.metadata.files[metadata_file]
                         ])
      end

      diff_command = %W(
        diff -u
        --label #{stack_promotion.cur.name}/#{metadata_file}
        #{stack_promotion.cur.metadata.files[metadata_file]}
        --label #{stack_promotion.nxt.name}/#{metadata_file}
        #{stack_promotion.nxt.metadata.files[metadata_file]}
      )
      diff_filename = output_dir.join("#{metadata_file}.diff")
      logger.info "writing #{diff_filename}"
      system(*diff_command, out: diff_filename.to_s)
    end
  end

  private def munge_rspec_json(rspec_json_files)
    rspec_json_files.each do |full_path|
      parsed = JSON.parse(File.read(full_path))
      parsed['examples'] = parsed['examples'].sort_by do |entry|
        entry['full_description']
      end
      File.write(full_path, JSON.pretty_generate(parsed))
    end
  end

  private def create_env_diff
    current_image_env = output_dir.join('current-image.env')
    current_image_env.write(
      stack_promotion.cur.metadata.env_hash
        .map { |k, v| [k, v] }
        .sort
        .map { |e| "#{e[0]}=#{e[1]}" }
        .join("\n") + "\n"
    )
    next_image_env = output_dir.join('next-image.env')
    next_image_env.write(
      stack_promotion.nxt.metadata.env_hash
        .map { |k, v| [k, v] }
        .sort
        .map { |e| "#{e[0]}=#{e[1]}" }
        .join("\n") + "\n"
    )
    diff_command = %W(
      diff -u
      --label #{stack_promotion.cur.name}/env
      #{current_image_env}
      --label #{stack_promotion.nxt.name}/env
      #{next_image_env}
    )
    diff_filename = output_dir.join('env.diff')
    logger.info "writing #{diff_filename}"
    system(*diff_command, out: diff_filename.to_s)
  end

  private def create_index_files
    packer_templates_diff_url = File.join(
      'https://github.com/travis-ci/packer-templates/compare',
      stack_promotion.cur.metadata.env_hash['PACKER_TEMPLATES_SHA'] + '...' +
      stack_promotion.nxt.metadata.env_hash['PACKER_TEMPLATES_SHA']
    )

    travis_cookbooks_diff_url = File.join(
      'https://github.com/travis-ci/travis-cookbooks/compare',
      stack_promotion.cur.metadata.env_hash['TRAVIS_COOKBOOKS_SHA'] + '...' +
      stack_promotion.nxt.metadata.env_hash['TRAVIS_COOKBOOKS_SHA']
    )

    output_files = output_dir.children.reject do |child|
      child.directory? || child.basename == 'README.md' ||
        child.basename == 'index.json'
    end

    create_readme_md(
      output_files,
      packer_templates_diff_url,
      travis_cookbooks_diff_url
    )

    create_index_json(
      output_files,
      packer_templates_diff_url,
      travis_cookbooks_diff_url
    )
  end

  private def create_readme_md(output_files,
                               packer_templates_diff_url,
                               travis_cookbooks_diff_url)
    readme_buf = []
    readme_buf << <<-EOF.gsub(/^\s+> ?/, '')
      > # #{stack_promotion.stack} promotion report
      >
      > - [packer-templates diff](#{packer_templates_diff_url})
      > - [travis-cookbooks diff](#{travis_cookbooks_diff_url})
      >
    EOF

    unless output_files.length.zero?
      readme_buf << '## output files'
      output_files.sort.each do |filename|
        readme_buf << "- [#{filename.basename}](./#{filename.basename})"
      end
    end

    readme = output_dir.join('README.md')
    logger.info "writing #{readme}"
    readme.write(readme_buf.join("\n"))
  end

  private def create_index_json(output_files,
                                packer_templates_diff_url,
                                travis_cookbooks_diff_url)
    index_json = output_dir.join('index.json')
    logger.info "writing #{index_json}"
    index_json.write(
      JSON.pretty_generate(
        stack: stack_promotion.stack,
        packer_templates_diff_url: packer_templates_diff_url,
        travis_cookbooks_diff_url: travis_cookbooks_diff_url,
        output_files: output_files.map(&:basename).map(&:to_s)
      )
    )
  end

  private def logger
    @logger ||= Logger.new($stdout)
  end
end
