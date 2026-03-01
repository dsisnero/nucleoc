module Nucleoc
  # Internal message representing a single match request.
  struct ParallelMatchRequest
    getter index : Int32
    getter haystack : String
    getter needle : String
    getter? compute_indices : Bool
    getter indices : Array(UInt32)
    getter response : Channel(ParallelMatchResponse)

    def initialize(@index, @haystack, @needle, @compute_indices, @indices, @response)
    end
  end

  # Result returned from a worker fiber.
  struct ParallelMatchResponse
    getter index : Int32
    getter score : UInt16?
    getter indices : Array(UInt32)?

    def initialize(@index, @score, @indices)
    end
  end

  # Simple worker pool that processes match requests concurrently using native Crystal channels.
  class WorkerPool
    getter size : Int32

    def self.default_size : Int32
      cpu_count = System.cpu_count
      size = cpu_count.is_a?(Int32) ? cpu_count : cpu_count.to_i32
      size.clamp(1, Int32::MAX)
    end

    def initialize(size : Int32 = WorkerPool.default_size, @config : Config = Config::DEFAULT)
      @size = size > 0 ? size : 1
      @work_channel = Channel(ParallelMatchRequest).new
      start_workers
    end

    # Submit a batch of haystacks to match against a single needle.
    # Returns scores (and optional indices) in the original order.
    def match_many(haystacks : Array(String), needle : String, compute_indices : Bool = false) : {Array(UInt16?), Array(Array(UInt32)?)?}
      response = Channel(ParallelMatchResponse).new

      # Submit tasks in separate fiber to avoid deadlock
      spawn do
        haystacks.each_with_index do |haystack, idx|
          @work_channel.send(
            ParallelMatchRequest.new(
              idx,
              haystack,
              needle,
              compute_indices,
              [] of UInt32,
              response
            )
          )
        end
      end

      scores = Array(UInt16?).new(haystacks.size, nil)
      indices = compute_indices ? Array(Array(UInt32)?).new(haystacks.size, nil) : nil

      haystacks.size.times do
        result = response.receive
        scores[result.index] = result.score
        if compute_indices && indices
          indices[result.index] = result.indices
        end
      end

      {scores, indices}
    end

    private def start_workers
      @size.times do
        matcher = Matcher.new(@config)
        spawn do
          loop do
            request = @work_channel.receive
            score = if request.compute_indices?
                      request.indices.clear
                      matcher.fuzzy_indices(request.haystack, request.needle, request.indices)
                    else
                      matcher.fuzzy_match(request.haystack, request.needle)
                    end
            copied_indices = request.compute_indices? ? request.indices.dup : nil
            request.response.send(ParallelMatchResponse.new(request.index, score, copied_indices))
          end
        end
      end
    end
  end
end
