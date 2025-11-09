# frozen_string_literal: true

# Autoload everything inside `lib/` using Zeitwerk
lib_path = Rails.root.join("lib")

loader = Zeitwerk::Loader.for_gem
loader.push_dir(lib_path)
loader.setup
