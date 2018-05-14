
class Matcher
  alias Map = Hash(String, Map)
  record Status, msg : String, line : String, keywords : Array(String)

  BUF_SIZE  = 10485760
  DELIMITER = " "

  @buf = Pointer(UInt8).null
  @vars = Hash(String, Regex).new
  @template = Hash(String, Map).new
  @status : Status?
  @tty : Bool = LibC.isatty(1) == 1

  def initialize
    abort "Usage:\n\t#{PROGRAM_NAME} vars.conf TEMPLATE < INPUT_FILE\n" if ARGV.size < 2
    @buf = Pointer(UInt8).malloc(BUF_SIZE)

    load_vars
    load_template
  end

  def run : Void
    errors = skipped = processed = total = 0
    content = ARGV.size > 2 ? read(ARGV[2]) : read
    elapsed = Time.measure do
      lines = content.split("\n")
      total = lines.size
      lines.each_with_index(1) do |line, n|
        basic_check
        ok = recursive_check(@template, line, true)
        print_error if !ok && (status = @status)
      end
    end
    print_stats
  end

  private macro basic_check
    line = line.strip
    if @template.keys.any? { |x| line.starts_with?(x) }
      processed += 1
    else
      skipped += 1 unless line.empty?
      next
    end
  end

  private macro load_vars
    read(ARGV[0]).strip.split("\n").map do |x|
      next unless x.includes?("=")
      k, v = x.split("=", 2).map &.strip
      next if k.starts_with?("#")
      @vars[k] = Regex.new("^" + v)
    end
  end

  private macro load_template
    read(ARGV[1]).strip.split("\n").map do |line|
      line = line.strip
      next if line.starts_with?("#")
      recursive_set(@template, line.split(DELIMITER))
    end
  end

  private macro print_error
    if @tty
      before = line.size - status.line.size
      printf("[Line: \e[1;33m%d\e[0m] \e[96m%s\e[0m. Expected: \e[1;33m%s\e[0m\n", n, status.msg, status.keywords.join(", "))
      puts line.size > 100 ? line[0..before + 20] + " ..." : line
      if before >= line.size
        puts " " + " " * before + "\e[0;31m" + "^^^\e[0m"
      else
        puts " " * before + "\e[0;31m" + "^" * status.line.split(" ")[0].size + "\e[0m"
      end
      errors += 1
    else
      print_error_plain
    end
  end

  private macro print_stats
    if @tty
      printf("Total: \e[1;37m%d\e[0m lines, ", total) if total > processed
      printf("Processed \e[1;33m%d\e[0m lines in \e[1;33m%0.3f\e[0m ms", processed, elapsed.nanoseconds / 1_000_000.0)
      printf(", skipped \e[1;37m%d\e[0m lines", skipped) if skipped > 0
      if errors > 0
        printf(", found \e[1;41m %d \e[0m issue(s)\n", errors)
        exit(1)
      else
        printf(", seems to be OK\n")
      end
    else
      print_stats_plain
    end
  end

  private macro print_error_plain
    before = line.size - status.line.size
    printf("[Line: %d] %s. Expected: %s\n", n, status.msg, status.keywords.join(", "))
    puts line.size > 100 ? line[0..before + 20] + " ..." : line
    if before >= line.size
      puts " " + " " * before + "" + "^^^"
    else
      puts " " * before + "" + "^" * status.line.split(" ")[0].size + ""
    end
    errors += 1
  end

  private macro print_stats_plain
    printf("Total: %d lines, ", total) if total > processed
    printf("Processed %d lines in %0.3f ms", processed, elapsed.nanoseconds / 1_000_000.0)
    printf(", skipped %d lines", skipped) if skipped > 0
    if errors > 0
      printf(", found  %d  issue(s)\n", errors)
      exit(1)
    else
      printf(", seems to be OK\n")
    end
  end

  private def read(name : String) : String
    fd = LibC.open(name, LibC::O_RDONLY)
    raise "Cannot open #{name}\n" if fd < 0
    ret = LibC.read(fd, @buf, BUF_SIZE)
    raise "Cannot read #{name}\n" if ret < 0
    LibC.close(fd)
    String.new(Slice.new(@buf, ret))
  end

  private def read : String
    ret = LibC.read(0, @buf, BUF_SIZE)
    raise "Cannot read stdin\n" unless ret > 0
    String.new(Slice.new(@buf, ret))
  end

  private def recursive_set(d, keys : Array(String)) : Void
    if keys.size == 1
      d[keys[0]] = Hash(String, Map).new
      d[keys[0]][""] = Hash(String, Map).new
    else
      d[keys[0]] = Hash(String, Map).new unless d.has_key?(keys[0])
      recursive_set(d[keys[0]], keys[1..-1])
    end
  end

  private macro check_delimiter(next_token)
    if {{next_token}}.empty?
      line = ""
    elsif {{next_token}}.starts_with?(DELIMITER)
      line = {{next_token}}.lstrip(DELIMITER)
    else
      found_key = nil
    end
    break
  end

  private def recursive_check(d, line : String, root = false) : Bool
    @status = nil if root
    return true if d.has_key?("") && line.empty?
    found_key = nil
    d.each_key do |k|
      if line.starts_with?(k + DELIMITER) || line == k
        found_key = k
        line = line[k.size..-1]
        check_delimiter(line)
      elsif @vars.has_key?(k) && (matched = @vars[k].match(line))
        found_key = k
        rest = line[matched.end(0).not_nil!..-1]
        check_delimiter(rest)
      end
    end
    if found_key
      if !line.empty?
        return recursive_check(d[found_key], line)
      elsif !d[found_key].has_key?("")
        @status = Status.new("Incomplete line", line, dump_keys(d[found_key]))
        return false
      end
    elsif !@status
      @status = Status.new("Unrecognized token", line, dump_keys(d))
    end
    !!found_key
  end

  private macro dump_keys(d)
    ({{d}}).keys.map { |x| (@vars.has_key?(x) ? "#{x}: /#{@vars[x].source}/" : x).to_s }
  end
end

Matcher.new.run

