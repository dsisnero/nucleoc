module Nucleoc
  # Fiber-only worker pool using Crystal's Channel and spawn.
  class FiberWorkerPool
    getter size : Int32
    getter config : Config

    private struct BatchJob
      getter start_idx : Int32
      getter haystacks : Array(String)
      getter needle : String
      getter? compute_indices : Bool
      getter reply_channel : Channel(BatchResult)

      def initialize(@start_idx, @haystacks, @needle, @compute_indices, @reply_channel)
      end
    end

    private struct BatchResult
      getter start_idx : Int32
      getter scores : Array(UInt16?)
      getter indices : Array(Array(UInt32)?)?

      def initialize(@start_idx, @scores, @indices)
      end
    end

    def initialize(size : Int32 = FiberWorkerPool.default_size, @config : Config = Config::DEFAULT)
      @size = size > 0 ? size : 1
      @work_channel = Channel(BatchJob).new
      start_workers
    end

    def self.default_size : Int32
      cpu_count = System.cpu_count
      size = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
      size.clamp(1, 16)
    end

    def match_many(haystacks : Array(String), needle : String, compute_indices : Bool = false) : {Array(UInt16?), Array(Array(UInt32)?)?}
      return {[] of UInt16?, nil} if haystacks.empty?

      response_ch = Channel(BatchResult).new
      chunk_size = chunk_size_for(haystacks.size)
      chunk_count = (haystacks.size + chunk_size - 1) // chunk_size
      normalized_needle = Matcher.new(@config).normalize_needle(needle)

      spawn do
        haystacks.each_slice(chunk_size).with_index do |slice, chunk_idx|
          start_idx = chunk_idx * chunk_size
          job = BatchJob.new(start_idx, slice, normalized_needle, compute_indices, response_ch)
          worker_idx = chunk_idx % @size
          @work_channel.send(job)
        end
      end

      scores = Array(UInt16?).new(haystacks.size, nil)
      indices = compute_indices ? Array(Array(UInt32)?).new(haystacks.size, nil) : nil

      chunk_count.times do
        result = response_ch.receive
        result.scores.each_with_index do |score, idx|
          scores[result.start_idx + idx] = score
        end
        if compute_indices && indices && result.indices
          result.indices.as(Array(Array(UInt32)?)).each_with_index do |idx_list, idx|
            indices[result.start_idx + idx] = idx_list
          end
        end
      end

      {scores, indices}
    end

    private def chunk_size_for(total : Int32) : Int32
      target_chunks = (@size * 4).clamp(1, 64)
      (total // target_chunks).clamp(1, total)
    end

    private def start_workers
      @size.times do
        matcher = Matcher.new(@config)
        indices_buffer = [] of UInt32

        spawn do
          loop do
            job = @work_channel.receive
            scores = Array(UInt16?).new(job.haystacks.size, nil)
            indices = job.compute_indices? ? Array(Array(UInt32)?).new(job.haystacks.size, nil) : nil

            job.haystacks.each_with_index do |haystack, idx|
              if job.compute_indices?
                indices_buffer.clear
                score = matcher.fuzzy_indices_normalized(haystack, job.needle, indices_buffer)
                scores[idx] = score
                indices.not_nil![idx] = indices_buffer.dup
              else
                scores[idx] = matcher.fuzzy_match_normalized(haystack, job.needle)
              end
            end

            job.reply_channel.send(BatchResult.new(job.start_idx, scores, indices))
          end
        end
      end
    end
  end
end
