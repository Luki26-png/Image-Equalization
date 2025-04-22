using Images, ImageView, DataFrames , Plots

# Fungsi untuk mengembalikan tabel histogram original dan histogram setelah equalization
function histogram_equalization_table(img)
    # Konversi ruang warna dari RGB ke LAB
    img = Lab.(img)

    # Ambil dimensi dari citra
    img_row, img_col = size(img)
    banyak_pixel = img_row * img_col

    # Membuat lightness parameters
    banyak_lightness = 101
    nilai_maksimum_lightness = 100

    # Inisialisasi arrays untuk lightness
    k = collect(0:nilai_maksimum_lightness)
    rₖ = k ./ nilai_maksimum_lightness
    nₖ = zeros(Int, banyak_lightness)

    # Hitung jumlah kemunculan untuk tiap lightness
    for x in 1:img_row, y in 1:img_col
        pixel_lightness = Int(round(img[x, y].l))
        nₖ[pixel_lightness + 1] += 1
    end    

    # Hitung Probability Density Function (PDF)
    pdf = nₖ ./ banyak_pixel
    histogram_equalization = DataFrame(k = k, rₖ = rₖ, nₖ = nₖ, pdf = pdf)

    # Cumulative Distribution Function (CDF)
    sₖ = ["s$i" for i in 0:nilai_maksimum_lightness]
    Tᵣ = copy(histogram_equalization.pdf)

    # Hitung CDF
    for i in 2:length(Tᵣ)
        Tᵣ[i] += Tᵣ[i - 1]
    end

    # Hitung pendekatan Tᵣ ke r
    pendekatan_ke_r = zeros(Float64, banyak_lightness)
    for i in 1:length(Tᵣ)
        min_selisih = Inf
        closest_r = NaN

        for j in 1:length(rₖ)
            selisih = abs(Tᵣ[i] - rₖ[j])
            if selisih < min_selisih
                min_selisih = selisih
                closest_r = rₖ[j]
            end
        end
        pendekatan_ke_r[i] = closest_r
    end

    # Buat Tabel CDF
    cdf_table = DataFrame("sₖ" => sₖ, "Tᵣ" => Tᵣ, "Pendekatan ke r" => pendekatan_ke_r)

    # Update nₖ berdasarkan hasil pendekatan ke r
    sₖ = copy(rₖ)
    nₖ = zeros(Int, banyak_lightness)
    global temp = 0

    for current in 1:length(pendekatan_ke_r) - 1
        current_r = pendekatan_ke_r[current]
        next_r = pendekatan_ke_r[current + 1]

        if current_r == next_r
            global temp += histogram_equalization.nₖ[current]
            continue
        end

        global temp += histogram_equalization.nₖ[current]
        nₖ[current] = temp
        global temp = 0
    end

    # Update nₖ untuk element terakhir
    if pendekatan_ke_r[101] == pendekatan_ke_r[100]
        nₖ[101] = histogram_equalization.nₖ[101] + nₖ[100]
        nₖ[100] = 0
    else
        nₖ[101] = histogram_equalization.nₖ[101]
    end

    # Hitung PDF yang baru
    pdf = nₖ ./ banyak_pixel
    equalized_table = DataFrame(sₖ = sₖ, new_intensity = pendekatan_ke_r, nₖ = nₖ, pdf = pdf)
    
    return Dict("original" => histogram_equalization, "hasil" => equalized_table, "cdf" => cdf_table)
end

# Fungsi untuk memplot histogram original
function plot_histogram_original(histogram_table::DataFrame)
    bar(histogram_table.rₖ, histogram_table.pdf, xlabel="Lightness (x)", ylabel="Frequency (y)", title="Histogram Original", legend=false)
end

# Fungsi untuk memplot histogram hasil
function plot_histogram_result(histogram_table::DataFrame)
    bar(histogram_table.new_intensity, histogram_table.pdf, xlabel="Lightness (x)", ylabel="Frequency (y)", title="Histogram Equalization", legend=false)
end

# Fungsi untuk memplot histogram spesifikasi
function plot_histogram_specification(histogram_table::DataFrame)
    bar(histogram_table.map, histogram_table.pdf, xlabel="Lightness (x)", ylabel="Frequency (y)", title="Histogram Specification", legend=false)
end

# Fungsi untuk membangun gambar yang telah di-equalize
function construct_equalized_img(original_img, equalized_table::DataFrame)
    original_img = Lab.(original_img)
    img_row, img_col = size(original_img)
    img_result = Array{Lab{Float32}, 2}(undef, img_row, img_col)

    for x in 1:img_row, y in 1:img_col
        current_l = Int(round(original_img[x, y].l))
        current_a = original_img[x, y].a
        current_b = original_img[x, y].b
        current_l = equalized_table.new_intensity[current_l + 1] * 100
        img_result[x, y] = Lab{Float32}(Float32(current_l), current_a, current_b)
    end

    return RGB.(img_result)
end

# Fungsi untuk membangun gambar berdasarkan spesifikasi
function construct_specification_img(original_img, specification_table::DataFrame)
    original_img = Lab.(original_img)
    img_row, img_col = size(original_img)
    img_result = Array{Lab{Float32}, 2}(undef, img_row, img_col)

    for x in 1:img_row, y in 1:img_col
        current_l = Int(round(original_img[x, y].l))
        current_a = original_img[x, y].a
        current_b = original_img[x, y].b
        current_l = specification_table.map[current_l + 1] * 100
        img_result[x, y] = Lab{Float32}(Float32(current_l), current_a, current_b)
    end

    return RGB.(img_result)
end

# Fungsi untuk melakukan histogram spesifikasi
function histogram_specification_table(original_img, img_ref)
    img_histogram_table = histogram_equalization_table(original_img)
    ref_img_histogram_table = histogram_equalization_table(img_ref)

    # Do mapping from original to specification
    mapping_table = DataFrame("original" => img_histogram_table["cdf"].Tᵣ, "reference" => ref_img_histogram_table["cdf"].Tᵣ)

    function map_arrays(original, specified)
        result = Int[]  # Initialize an empty array to store the result

        for value in original
            closest_value = specified[1]
            closest_index = 1
            min_diff = abs(value - closest_value)

            for (i, specified_value) in enumerate(specified)
                diff = abs(value - specified_value)
                if diff < min_diff || (diff == min_diff && i < closest_index)
                    closest_value = specified_value
                    closest_index = i
                    min_diff = diff
                end
            end

            push!(result, closest_index - 1)  # Subtract 1 to convert to 0-based index
        end

        return result
    end

    result = map_arrays(mapping_table.original, mapping_table.reference)
    mapping_table.map = result ./ 100

    # table kosong untuk menyimpan hasil histogram specification
    specification_result = DataFrame()
    sₖ = ["s$i" for i in 0:100]
    original_pdf = img_histogram_table["original"].pdf
    pdf = zeros(Float64, length(original_pdf))
    global temp = 0

    for current in 1:length(mapping_table.map) - 1
        current_r = mapping_table.map[current]
        next_r = mapping_table.map[current + 1]

        if current_r == next_r
            global temp += original_pdf[current]
            continue
        end

        global temp += original_pdf[current]
        pdf[current] = temp
        global temp = 0
    end

    # Update nₖ untuk elemen terakhir
    if mapping_table.map[101] == mapping_table.map[100]
        pdf[101] = original_pdf[101] + pdf[100]
        pdf[100] = 0
    else
        pdf[101] = original_pdf[101]
    end

    specification_result.sₖ = sₖ
    specification_result.map = result ./ 100
    specification_result.pdf = pdf

    return specification_result
end

# Load original image
img = load("pelican.jpg")

#img_equalization = histogram_equalization_table(img)

#plot_histogram_original(img_equalization["original"])

#plot_histogram_result(img_equalization["hasil"])

#equalized_img = construct_equalized_img(img, img_equalization["hasil"])
#imshow(equalized_img)

#Load reference image
img_ref = load("ref_img.jpg")

# Proses histogram spesifikasi
specification_result = histogram_specification_table(img, img_ref)

# Plot the specification histogram
plot_histogram_specification(specification_result)

# Create the image after doing histogram specification
img_after_specification = construct_specification_img(img, specification_result)
imshow(img_after_specification)
