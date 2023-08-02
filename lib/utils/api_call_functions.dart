import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './shared_pref_keys.dart' as pref_keys;
import 'api_call.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'classes.dart';

class ApiCallFunctions {
  ApiCall apiCall = ApiCall();

  String generateMd5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<String?> register({
    required String pNume,
    required String pPrenume,
    required String pTelefonMobil,
    required String pDataDeNastereYYYYMMDD,
    required String pAdresaMail,
    required String pParola,
    required String pFirebaseGoogleDeviceID,
  }) async {
    final String pParolaMD5 = generateMd5(pParola);
    final Map<String, String> parametriiApiCall = {
      'pNume': pNume,
      'pPrenume': pPrenume,
      'pTelefonMobil': pTelefonMobil,
      'pDataDeNastereYYYYMMDD': pDataDeNastereYYYYMMDD,
      'pAdresaMail': pAdresaMail,
      'pParolaMD5': pParolaMD5,
      'pTipDispozitiv': Platform.isAndroid
          ? '1'
          : Platform.isIOS
              ? '2'
              : '0',
      'pModelDispozitiv': await deviceInfo(),
      'pFirebaseGoogleDeviceID': pFirebaseGoogleDeviceID,
      'pLimbaSelectata': '1',
    };

    String? res = await apiCall.apeleazaMetodaString(
        pNumeMetoda: 'AdaugaPacient', pParametrii: parametriiApiCall, afiseazaMesajPacientNeasociat: false);

    return res;
  }

  Future<String?> login({
    required String pAdresaEmail,
    required String pParolaMD5,
    required String pFirebaseGoogleDeviceID,
  }) async {
    final Map<String, String> param = {
      'pAdresaEmail': pAdresaEmail,
      'pParolaMD5': pParolaMD5,
      'pFirebaseGoogleDeviceID': pFirebaseGoogleDeviceID,
      'pTipDispozitiv': Platform.isAndroid
          ? '1'
          : Platform.isIOS
              ? '2'
              : '0',
      'pModelDispozitiv': await deviceInfo(),
    };

    String? res = await apiCall.apeleazaMetodaString(
        pNumeMetoda: 'Login', pParametrii: param, afiseazaMesajPacientNeasociat: false);

    return res;
  }

  Future<Programari?> getListaProgramari() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // final String idUser = prefs.getString(pref_keys.userIdAjustareCurenta)!;
    final Map<String, String> param = {
      'pIdLimba': '0',
      "pAdresaMail": prefs.getString(pref_keys.userEmail)!,
      "pParolaMD5": prefs.getString(pref_keys.userPassMD5)!
    };

    String? res = await apiCall.apeleazaMetodaString(pNumeMetoda: 'GetListaProgramarileLui', pParametrii: param);

    List<Programare> programariViitoare = <Programare>[];
    List<Programare> programariTrecute = <Programare>[];
    if (res == null) {
      return null;
    }
    if (res.contains('%\$%')) {
      List<String> list = res.split('%\$%');

      List<String> viitoare = list[0].split('*\$*');
      List<String> trecute = list[1].split('*\$*');
      viitoare.removeWhere((element) => element.isEmpty);
      trecute.removeWhere((element) => element.isEmpty);

      for (var element in viitoare) {
        List<String> l = element.split('\$#\$');

        DateTime date = DateTime.utc(
          int.parse(l[0].substring(0, 4)),
          int.parse(l[0].substring(4, 6)),
          int.parse(l[0].substring(6, 8)),
          int.parse(l[0].substring(8, 10)),
          int.parse(l[0].substring(10, 12)),
        );
        DateTime dateSf = DateTime.utc(
          int.parse(l[0].substring(0, 4)),
          int.parse(l[0].substring(4, 6)),
          int.parse(l[0].substring(6, 8)),
          int.parse(l[1].substring(0, 2)),
          int.parse(l[1].substring(3, 5)),
        );

//TODO verif
        Programare p = Programare(
            nume: '',
            prenume: '',
            idPacient: '',
            medic: l[2],
            categorie: l[3],
            status: l[4],
            anulata: l[5] == '1',
            inceput: date,
            sfarsit: dateSf,
            id: l[6]);
        programariViitoare.add(p);
      }

      for (var element in trecute) {
        List<String> l = element.split('\$#\$');
//data inceput, ora final, identitate medic, categorie, status programare, 0/1 (este sau nu anulata)
        DateTime date = DateTime.utc(
          int.parse(l[0].substring(0, 4)),
          int.parse(l[0].substring(4, 6)),
          int.parse(l[0].substring(6, 8)),
          int.parse(l[0].substring(8, 10)),
          int.parse(l[0].substring(10, 12)),
        );
        DateTime dateSf = DateTime.utc(
          int.parse(l[0].substring(0, 4)),
          int.parse(l[0].substring(4, 6)),
          int.parse(l[0].substring(6, 8)),
          int.parse(l[1].substring(0, 2)),
          int.parse(l[1].substring(3, 5)),
        );
//TODO verif
        Programare p = Programare(
            nume: '',
            prenume: '',
            idPacient: '',
            id: l[6],
            medic: l[2],
            categorie: l[3],
            status: l[4],
            anulata: l[5] == '1',
            inceput: date,
            sfarsit: dateSf);
        programariTrecute.add(p);
      }
    }
    programariTrecute.sort((a, b) => b.inceput.compareTo(a.inceput));
    programariViitoare.sort((a, b) => a.inceput.compareTo(b.inceput));
    return Programari(trecute: programariTrecute, viitoare: programariViitoare);
  }

  Future<String> deviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String device = '';
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.utsname.machine;
    }
    return device;
  }

  Future<void> anuleazaProgramarea(String pIdProgramare) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, String> params = {
      // 'pCheie': 'uniqueID',
      'pAdresaMail': prefs.getString(pref_keys.userEmail)!,
      'pParolaMD5': prefs.getString(pref_keys.userPassMD5)!,
      'pIdProgramare': pIdProgramare,
    };
    await apiCall.apeleazaMetodaString(pNumeMetoda: 'AnuleazaProgramarea', pParametrii: params);
  }

  Future<void> confirmaProgramarea(String pIdProgramare) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, String> params = {
      // 'pCheie': 'uniqueID',
      'pAdresaMail': prefs.getString(pref_keys.userEmail)!,
      'pParolaMD5': prefs.getString(pref_keys.userPassMD5)!,
      'pIdProgramare': pIdProgramare,
    };
    await apiCall.apeleazaMetodaString(pNumeMetoda: 'ConfirmaProgramarea', pParametrii: params);
  }

  Future<List<LinieFisaTratament>?> getListaLiniiFisaTratamentRealizate(MembruFamilie membruFamilie) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> params = {
      'pAdresaMail': prefs.getString(pref_keys.userEmail)!,
      'pParolaMD5': prefs.getString(pref_keys.userPassMD5)!,
    };

    String? res =
        await apiCall.apeleazaMetodaString(pNumeMetoda: 'GetListaLiniiFisaTratamentRealizate', pParametrii: params);

    List<LinieFisaTratament> interventii = <LinieFisaTratament>[];
    if (res == null) {
      return null;
    }
    if (res.contains('*\$*')) {
      List<String> interventiiRaw = res.split('*\$*');
      interventiiRaw.removeWhere((v) => v.isEmpty);

      for (var interv in interventiiRaw) {
        List<String> list = interv.split('\$#\$');

        DateTime dateTime = DateTime.utc(
            int.parse(list[6].substring(0, 4)), int.parse(list[6].substring(4, 6)), int.parse(list[6].substring(6, 8)));

        String data = DateFormat('dd.MM.yyyy').format(dateTime);

        interventii.add(LinieFisaTratament(
            tipObiect: list[0],
            idObiect: list[1],
            numeMedic: list[2],
            denumireInterventie: list[3],
            dinti: list[4],
            observatii: list[5],
            dataDateTime: dateTime,
            dataString: data,
            pret: list[7],
            culoare: Color(int.parse(list[8])),
            valoareInitiala: list[9]));
      }
    }
    return interventii;
  }

  Future<DetaliiProgramare?> getDetaliiProgramare(String pIdProgramare) async {
    ApiCall apiCall = ApiCall();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, String> params = {
      // 'pCheie': 'uniqueID',
      'pAdresaMail': prefs.getString(pref_keys.userEmail)!,
      'pParolaMD5': prefs.getString(pref_keys.userPassMD5)!,
      'pIdProgramare': pIdProgramare,
    };
    String? lmao = await apiCall.apeleazaMetodaString(pNumeMetoda: 'GetDetaliiProgramare', pParametrii: params);
    print(lmao);
    List<String>? ayy = lmao?.split('%\$%');
    if (lmao == null) {
      return null;
    } else {
      return null;
    }
  }

  Future<String?> reseteazaParola({
    required String pAdresaMail,
    required String pParolaNoua,
  }) async {
    final String pParolaNouaMD5 = generateMd5(pParolaNoua);

    final Map<String, String> param = {'pAdresaMail': pAdresaMail, 'pParolaNouaMD5': pParolaNouaMD5};

    String? res = await apiCall.apeleazaMetodaString(pNumeMetoda: 'ReseteazaParola', pParametrii: param);
    return res;
  }
}
