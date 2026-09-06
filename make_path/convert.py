import csv

class Converter:
    def latlong2xy(self, lat, long):
        from math import pi, tan, log, cos, sin, floor

        RE = 6371.00877     # 지구 반경(km)
        GRID = 0.0000005    # 격자 간격(km), 0.5mm단위
        SLAT1 = 30.0
        SLAT2 = 60.0
        OLON = 126.0
        OLAT = 38.0
        XO = 43
        YO = 136

        DEGRAD = pi / 180.0
        re = RE / GRID
        slat1 = SLAT1 * DEGRAD
        slat2 = SLAT2 * DEGRAD
        olon = OLON * DEGRAD
        olat = OLAT * DEGRAD

        sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5)
        sn = log(cos(slat1) / cos(slat2)) / log(sn)
        sf = tan(pi * 0.25 + slat1 * 0.5)
        sf = pow(sf, sn) * cos(slat1) / sn
        ro = tan(pi * 0.25 + olat * 0.5)
        ro = re * sf / pow(ro, sn)

        ra = tan(pi * 0.25 + (lat) * DEGRAD * 0.5)
        ra = re * sf / pow(ra, sn)

        theta = long * DEGRAD - olon
        if theta > pi:
            theta -= 2.0 * pi
        if theta < -pi:
            theta += 2.0 * pi
        theta *= sn
        rs_x = floor(ra * sin(theta) + XO + 0.5)
        rs_y = floor(ro - ra * cos(theta) + YO + 0.5)
        # 제주
        first_xx = 0
        first_yy = 0
        # 계룡?
        # first_xx = -107981.357
        # first_yy = 186833.4085
        # 충북대
        # first_xx = -125320
        # first_yy = 136746
        rs_x = rs_x/2000 + first_xx
        rs_y = rs_y/2000 + first_yy

        return rs_x, rs_y

def convert_and_save(csv_filename, txt_filename):
    converter = Converter()

    with open(csv_filename, mode='r') as csv_file:
        csv_reader = csv.reader(csv_file)

        # next(csv_reader)  # 첫 번째 줄이 헤더일 때 건너뛰기
        
        with open(txt_filename, mode='w') as txt_file:
            for row in csv_reader:
                lat = float(row[1])
                long = float(row[0])
                x, y = converter.latlong2xy(lat, long)
                x = round(x, 8)
                y = round(y, 8)
                txt_file.write(f"{x}\t{y}\n")

convert_and_save('gps_data_ublox_out.csv', 'new_data_out.txt')
convert_and_save('gps_data_ublox_in.csv', 'new_data_in.txt')


# convert_and_save('jejuraw2.csv', 'rawdata_out_temp.txt')
# convert_and_save('0504_out_gps.csv', 'rawdata_out_temp.txt')
# convert_and_save('0905_OUT.csv', 'rawdata_OUT.txt')
