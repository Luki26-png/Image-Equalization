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
