using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Array
{
    class Program
    {
        public static void Main(string[] args)
        {
            int baris = 2;
            Console.Write("Masukkan Kolom : ");
            int kolom = int.Parse(Console.ReadLine());
            int deret3 = 1;
            int[,] arr2Dimensi = new int[baris, kolom];

            for (int i = 0; i < baris; i++)
            {
                for (int j = 0; j < kolom; j++)
                {
                    if (i == 0)
                    {
                        arr2Dimensi[i, j] = j;
                    }
                    else
                    {
                        arr2Dimensi[i, j] = deret3;
                        deret3 *= 3;

                    }
                }
            }



            for (int i = 0; i < baris; i++)
            {
                for (int j = 0; j < kolom; j++)
                {
                    Console.Write(arr2Dimensi[i, j] + "  ");
                }
                Console.WriteLine();

               
            }
            Console.ReadKey();
        }
    }
}
