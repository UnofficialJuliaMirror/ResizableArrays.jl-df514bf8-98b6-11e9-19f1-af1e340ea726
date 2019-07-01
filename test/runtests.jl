module ResizableArraysTests

using Test
using ResizableArrays
using ResizableArrays: checkdimension, checkdimensions

# FIXME: used @generated
slice(A::AbstractArray{<:Any,2}, I) = A[:,I]
slice(A::AbstractArray{<:Any,3}, I) = A[:,:,I]
slice(A::AbstractArray{<:Any,4}, I) = A[:,:,:,I]
slice(A::AbstractArray{<:Any,5}, I) = A[:,:,:,:,I]

@testset "Basic methods" begin
    @testset "Utilities" begin
        @test checkdimension(Bool, π) == false
        @test checkdimensions(Bool, ()) == true
        @test checkdimensions(Bool, (1,)) == true
        @test checkdimensions(Bool, (1,2,0)) == true
        @test checkdimensions(Bool, (1,-2,0)) == false
        @test_throws ErrorException checkdimensions((1,-2,0))
        @test isgrowable(π) == false
        @test isgrowable((1,2,3)) == false
        @test isgrowable([1,2,3]) == true
    end
    @testset "Dimensions: $dims" for dims in ((), (3,), (2,3), (2,3,4))
        N = length(dims)
        if N > 0
            A = rand(dims...)
            T = eltype(A)
        else
            T = Float64
            A = Array{T}(undef, dims)
            A[1] = rand(dims...)
        end
        B = ResizableArray{T}(undef, size(A))
        @test isgrowable(B) == (N > 0)
        @test IndexStyle(typeof(B)) == IndexLinear()
        @test eltype(B) == eltype(A)
        @test ndims(B) == ndims(A) == N
        @test size(B) == size(A)
        @test all(d -> size(B,d) == size(A,d), 1:(N+2))
        @test axes(B) == axes(A)
        @test Base.axes1(B) == axes(B,1)
        @test length(B) == length(A) == prod(dims)
        @test maxlength(B) == length(B)
        @test all(d -> axes(B,d) == axes(A,d), 1:(N+2))
        copyto!(B, A)
        @test all(i -> A[i] == B[i], 1:length(A))
        @test all(i -> A[i] == B[i], CartesianIndices(A))
        @test all(i -> A[i] == B.vals[i], 1:length(A))
        @test A == B
        for i in eachindex(B)
            B[i] = rand()
        end
        copyto!(A, B)
        @test A == B
        if N > 0
            dims16b = map(Int16, size(A)) # used later
            # Extend array B.
            tmpdims = collect(size(B))
            tmpdims[end] += 1
            resize!(B, tmpdims...)
            for i in length(A)+1:length(B); B[i] = 0; end
            @test maxlength(B) == length(B) == prod(tmpdims)
            @test A != B
            @test B != A
            @test all(i -> B[i] == A[i], 1:length(A))
            C = view(B, axes(A)...)
            @test C != B && B != C
            @test C == A && A == C
            # Shrink array B.
            oldmaxlen = maxlength(B)
            resize!(B, dims)
            @test B == A
            @test C == B && B == C
            @test maxlength(B) == oldmaxlen
            C = copy(ResizableArray, B)
            @test C == B
            @test maxlength(C) == length(C)
            C = copy(ResizableArray{T}, B)
            @test C == B
            @test maxlength(C) == length(C)
            C = copy(ResizableArray{T,N}, B)
            @test C == B
            @test maxlength(C) == length(C)
            shrink!(B)
            @test B == A
            @test maxlength(B) == length(B)
        end
        @test_throws BoundsError B[0]
        @test_throws BoundsError B[length(B) + 1]
        @test_throws ErrorException resize!(B, (dims..., 5))

        # Check various constructors and custom buffer
        # (do not splat dimensions if N=0).
        buf = Vector{T}(undef, length(A))
        for arg in (undef, buf)
            C = copyto!(ResizableArray{T}(arg, dims), A)
            @test eltype(C) == eltype(A) && C == A
            C = copyto!(ResizableArray{T,N}(arg, dims), A)
            @test eltype(C) == eltype(A) && C == A
            if N > 0
                C = copyto!(ResizableArray{T}(arg, dims...), A)
                @test eltype(C) == eltype(A) && C == A
                C = copyto!(ResizableArray{T,N}(arg, dims...), A)
                @test eltype(C) == eltype(A) && C == A
                C = copyto!(ResizableArray{T}(arg, dims16b), A)
                @test eltype(C) == eltype(A) && C == A
                C = copyto!(ResizableArray{T}(arg, dims16b...), A)
                @test eltype(C) == eltype(A) && C == A
                C = copyto!(ResizableArray{T,N}(arg, dims16b), A)
                @test eltype(C) == eltype(A) && C == A
                C = copyto!(ResizableArray{T,N}(arg, dims16b...), A)
                @test eltype(C) == eltype(A) && C == A
            end
        end

        # Use constructor to convert array.
        C = ResizableArray{T,N}()
        resize!(C, dims)
        copyto!(C, A)
        @test eltype(C) == eltype(A) && C == A

        # Use constructor to convert array.
        C = ResizableArray(A)
        @test eltype(C) == eltype(A) && C == A
        C = ResizableArray{T}(A)
        @test eltype(C) == eltype(A) && C == A
        C = ResizableArray{T,N}(A)
        @test eltype(C) == eltype(A) && C == A

        # Use convert to convert array.
        C = convert(ResizableArray, A)
        @test eltype(C) == eltype(A) && C == A
        C = convert(ResizableArray{T}, A)
        @test eltype(C) == eltype(A) && C == A
        C = convert(ResizableArray{T,N}, A)
        @test eltype(C) == eltype(A) && C == A
    end
end

@testset "Queue methods" begin
    T = Float32
    @testset "Dimensions: $dims" for dims in ((3,), (2,3), (2,3,4))
        N = length(dims)
        m = 3
        A = rand(T, dims..., m)
        B = rand(T, dims)
        C = rand(T, dims)
        R = ResizableArray(A)
        append!(R, B)
        @test slice(R, 1:m) == A
        @test slice(R, m+1) == B
        prepend!(R, C)
        @test slice(R, 1) == C
        @test slice(R, 2:m+1) == A
        @test slice(R, m+2) == B
    end
end

end # module
